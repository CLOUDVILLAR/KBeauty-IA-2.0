import io
import json
import re
from datetime import datetime
from html import escape
from urllib.parse import quote

from fastapi import APIRouter, Request, Form, File, UploadFile, Query
from fastapi.responses import HTMLResponse, RedirectResponse, FileResponse, Response

from servicios.servicio_kbeauty_data import (
    ROLES_ADMIN,
    ROLES_EMPLEADO,
    asignar_rol_a_villar_id,
    buscar_clientes,
    construir_url_login_sso,
    crear_rol,
    codigos_roles,
    exigir_admin,
    exigir_empleado,
    extraer_token_callback,
    guardar_pdf_presencial,
    intercambiar_codigo_sso,
    listar_roles,
    listar_usuarios_kbeauty,
    obtener_pdf_presencial,
    obtener_cliente_kdata,
    usuario_desde_token_web,
    usuario_tiene_rol,
)
from config.configuracion import VILLAR_DO_API_URL, VILLAR_DO_CLIENT_ID
from servicios.servicio_rutinas import listar_rutinas
from utilidades.respuestas import respuesta_correcta, respuesta_error

router = APIRouter(tags=["KBEAUTY-DATA"])
COOKIE = "kbeauty_data_token"


def _redirect_login_limpiando_sesion(destino: str):
    respuesta = RedirectResponse(f"/kbeauty-data/login?next={quote(destino)}", status_code=302)
    respuesta.delete_cookie(COOKIE)
    return respuesta


def _texto_pdf(valor):
    """Limpia texto para PDF usando codificacion Windows-1252.

    El PDF manual necesita WinAnsiEncoding/cp1252 para que acentos como
    "Después" no terminen como caracteres raros, por ejemplo "DespuØs".
    """
    texto = str(valor or "").replace("\r", " ").replace("\n", " ").strip()
    reemplazos = {
        "•": "-",
        "–": "-",
        "—": "-",
        "−": "-",
        "“": '"',
        "”": '"',
        "„": '"',
        "‘": "'",
        "’": "'",
        "‚": "'",
        "…": "...",
        " ": " ",
        "​": "",
        "﻿": "",
    }
    for origen, destino in reemplazos.items():
        texto = texto.replace(origen, destino)
    texto = re.sub(r"\s+", " ", texto).strip()
    return texto.encode("cp1252", "replace").decode("cp1252")


def _pdf_escape(valor):
    texto = _texto_pdf(valor)
    return texto.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def _pdf_stream_bytes(contenido):
    return contenido.encode("cp1252", "replace")


def _ancho_aprox_pdf(texto, size=9):
    """Aproximacion conservadora del ancho en puntos para Helvetica.

    Evita que el PDF se coma palabras cuando hay nombres o descripciones largas.
    """
    ancho = 0.0
    for ch in _texto_pdf(texto):
        if ch in "ilI.,'|!":
            factor = 0.28
        elif ch in "mwMW@#%&":
            factor = 0.88
        elif ch == " ":
            factor = 0.30
        elif ch.isupper():
            factor = 0.66
        else:
            factor = 0.52
        ancho += size * factor
    return ancho


def _dividir_palabra_pdf(palabra, max_width, size):
    partes = []
    actual = ""
    for ch in palabra:
        candidato = actual + ch
        if actual and _ancho_aprox_pdf(candidato, size) > max_width:
            partes.append(actual)
            actual = ch
        else:
            actual = candidato
    if actual:
        partes.append(actual)
    return partes or [palabra]


def _wrap_pdf(valor, ancho=82, size=9, max_width=None):
    texto = _texto_pdf(valor)
    if not texto:
        return [""]

    # Compatibilidad: el codigo viejo pasaba ancho como cantidad aproximada
    # de caracteres. Convertimos eso a puntos para medir mejor.
    if max_width is None:
        max_width = max(40, ancho * size * 0.52)

    palabras = texto.split()
    lineas = []
    linea = ""

    for palabra in palabras:
        subpartes = _dividir_palabra_pdf(palabra, max_width, size)
        for parte in subpartes:
            candidato = f"{linea} {parte}".strip()
            if linea and _ancho_aprox_pdf(candidato, size) > max_width:
                lineas.append(linea)
                linea = parte
            else:
                linea = candidato
    if linea:
        lineas.append(linea)
    return lineas or [""]


def _producto_pdf_lineas(producto, momento):
    nombre = producto.get("nombre_producto") or producto.get("nombre") or "Producto"
    paso = ((producto.get("uso") or {}).get("paso_rutina") or producto.get("categoria") or "producto")
    id_odoo = producto.get("id_odoo")
    descripcion = producto.get("descripcion_rutina") or {}
    if momento == "dia":
        desc = descripcion.get("día") or descripcion.get("dia") or descripcion.get("mañana") or descripcion.get("manana") or ""
    else:
        desc = descripcion.get("noche") or descripcion.get("día") or descripcion.get("dia") or ""
    subtitulo = f"Paso: {paso}"
    if id_odoo:
        subtitulo += f" | ID Odoo: {id_odoo}"
    return nombre, subtitulo, desc


def _productos_momento_pdf(rutina, momento):
    bloques = (rutina or {}).get("rutina") or {}
    if momento == "dia":
        return list(bloques.get("mañana") or []) + list(bloques.get("día") or []) + list(bloques.get("dia") or [])
    return list(bloques.get("noche") or [])


def _crear_pdf_rutina_no_app(cliente_nombre, cliente_telefono, rutina):
    """Genera el PDF bonito de rutina para cliente sin app.

    No guarda datos, no usa IA y se mantiene liviano para poder unirlo rapido
    con el PDF original de la maquina.
    """
    cliente_nombre = _texto_pdf(cliente_nombre) or "Cliente sin app"
    cliente_telefono = _texto_pdf(cliente_telefono) or "No indicado"
    nombre_rutina = _texto_pdf((rutina or {}).get("nombre") or "Rutina KBeauty")
    tipo_piel = _texto_pdf((rutina or {}).get("tipo_piel") or "N/D")
    condicion = _texto_pdf((rutina or {}).get("condicion") or "N/D")
    fecha = datetime.now().strftime("%d/%m/%Y %I:%M %p")

    paginas = []
    comandos = []
    y = 742

    def nueva_pagina():
        nonlocal comandos, y
        if comandos:
            paginas.append("\n".join(comandos))
        comandos = [
            "0.998 0.948 0.958 rg 0 0 612 792 re f",
            "1 1 1 rg 36 36 540 720 re f",
            "0.961 0.114 0.216 rg 36 682 540 74 re f",
            "1 0.72 0.76 rg 36 682 540 5 re f",
            "1 1 1 rg BT /F2 27 Tf 58 724 Td (KBeauty IA) Tj ET",
            "1 1 1 rg BT /F1 10 Tf 58 706 Td (Rutina presencial para cliente sin app) Tj ET",
            f"1 1 1 rg BT /F2 9 Tf 430 724 Td (Fecha) Tj ET",
            f"1 1 1 rg BT /F1 9 Tf 430 708 Td ({_pdf_escape(fecha)}) Tj ET",
            "0.18 0.15 0.18 rg",
        ]
        y = 654

    def texto(x, yy, valor, size=10, bold=False, color="0.18 0.15 0.18"):
        fuente = "/F2" if bold else "/F1"
        comandos.append(f"{color} rg BT {fuente} {size} Tf {x} {yy} Td ({_pdf_escape(valor)}) Tj ET")

    def rect(x, yy, w, h, color):
        comandos.append(f"{color} rg {x} {yy} {w} {h} re f")

    def linea(x1, yy, x2, color="0.98 0.80 0.84"):
        comandos.append(f"{color} RG {x1} {yy} m {x2} {yy} l S")

    def asegurar(altura=42):
        nonlocal y
        if y - altura < 60:
            nueva_pagina()

    def parrafo(valor, x=58, size=9, ancho=88, line_height=14, color="0.34 0.31 0.35"):
        nonlocal y
        for linea_txt in _wrap_pdf(valor, ancho, size=size):
            asegurar(line_height + 8)
            texto(x, y, linea_txt, size, False, color)
            y -= line_height

    def etiqueta_valor(x, yy, etiqueta, valor, ancho=34):
        texto(x, yy, etiqueta, 8, True, "0.52 0.47 0.53")
        yy -= 15
        for i, linea_txt in enumerate(_wrap_pdf(valor, ancho, size=11, max_width=210)[:3]):
            texto(x, yy - (i * 14), linea_txt, 11 if i == 0 else 9, True, "0.18 0.15 0.18")

    def bloque_titulo(titulo, emoji_texto=""):
        nonlocal y
        asegurar(48)
        rect(48, y - 10, 516, 34, "1 0.965 0.972")
        rect(48, y - 10, 7, 34, "0.961 0.114 0.216")
        texto(64, y, f"{emoji_texto}{titulo}", 14, True, "0.18 0.15 0.18")
        y -= 44

    nueva_pagina()

    # Datos del cliente en tarjetas separadas para evitar cruces visuales.
    rect(52, 568, 248, 100, "1 0.985 0.988")
    rect(312, 568, 248, 100, "1 0.985 0.988")
    etiqueta_valor(68, 642, "CLIENTE", cliente_nombre, ancho=28)
    etiqueta_valor(328, 646, "TELEFONO", cliente_telefono, ancho=27)
    texto(328, 592, "FECHA", 8, True, "0.52 0.47 0.53")
    texto(328, 577, fecha, 9, True, "0.18 0.15 0.18")

    y = 528
    rect(52, y - 22, 508, 78, "1 1 1")
    rect(52, y - 22, 508, 3, "1 0.87 0.90")
    texto(68, y + 24, "Rutina seleccionada", 9, True, "0.52 0.47 0.53")
    yy = y + 5
    for linea_txt in _wrap_pdf(nombre_rutina, 48, size=17, max_width=455)[:2]:
        texto(68, yy, linea_txt, 17, True, "0.961 0.114 0.216")
        yy -= 20
    texto(68, y - 35, f"Tipo de piel: {tipo_piel}", 10, True, "0.18 0.15 0.18")
    texto(306, y - 35, f"Condicion: {condicion}", 10, True, "0.18 0.15 0.18")
    y -= 78

    bloque_titulo("Rutina de Dia")
    productos_dia = _productos_momento_pdf(rutina, "dia")
    if not productos_dia:
        parrafo("No hay productos configurados para este momento.")
    for idx, producto in enumerate(productos_dia, 1):
        nombre, subtitulo, desc = _producto_pdf_lineas(producto, "dia")
        asegurar(68)
        rect(58, y - 8, 494, 2, "1 0.92 0.94")
        texto(58, y, f"{idx}. {nombre}", 11, True, "0.18 0.15 0.18")
        y -= 15
        parrafo(subtitulo, x=72, size=8, ancho=76, line_height=12, color="0.52 0.47 0.53")
        if desc:
            parrafo(desc, x=72, size=8, ancho=78, line_height=12)
        y -= 12

    bloque_titulo("Rutina de Noche")
    productos_noche = _productos_momento_pdf(rutina, "noche")
    if not productos_noche:
        parrafo("No hay productos configurados para este momento.")
    for idx, producto in enumerate(productos_noche, 1):
        nombre, subtitulo, desc = _producto_pdf_lineas(producto, "noche")
        asegurar(68)
        rect(58, y - 8, 494, 2, "1 0.92 0.94")
        texto(58, y, f"{idx}. {nombre}", 11, True, "0.18 0.15 0.18")
        y -= 15
        parrafo(subtitulo, x=72, size=8, ancho=76, line_height=12, color="0.52 0.47 0.53")
        if desc:
            parrafo(desc, x=72, size=8, ancho=78, line_height=12)
        y -= 12

    asegurar(70)
    rect(52, y - 36, 508, 58, "1 0.965 0.972")
    texto(68, y, "Nota para entrega", 10, True, "0.961 0.114 0.216")
    y -= 14
    parrafo("Esta rutina fue seleccionada manualmente por el empleado desde el catalogo KBeauty. El reporte original de la maquina se adjunta despues de esta portada cuando fue cargado.", x=68, size=8, ancho=82, line_height=12)

    if comandos:
        paginas.append("\n".join(comandos))

    objetos = []
    objetos.append("<< /Type /Catalog /Pages 2 0 R >>")
    kids = " ".join(f"{5 + i * 2} 0 R" for i in range(len(paginas)))
    objetos.append(f"<< /Type /Pages /Kids [{kids}] /Count {len(paginas)} >>")
    objetos.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    objetos.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
    for i, contenido in enumerate(paginas):
        content_obj = 6 + i * 2
        objetos.append(f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents {content_obj} 0 R >>")
        stream = _pdf_stream_bytes(contenido)
        objetos.append(f"<< /Length {len(stream)} >>\nstream\n{stream.decode('cp1252', 'replace')}\nendstream")

    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for idx, obj in enumerate(objetos, 1):
        offsets.append(len(pdf))
        pdf.extend(f"{idx} 0 obj\n".encode("ascii"))
        pdf.extend(obj.encode("cp1252", "replace"))
        pdf.extend(b"\nendobj\n")
    xref = len(pdf)
    pdf.extend(f"xref\n0 {len(objetos)+1}\n0000000000 65535 f \n".encode("ascii"))
    for off in offsets[1:]:
        pdf.extend(f"{off:010d} 00000 n \n".encode("ascii"))
    pdf.extend(f"trailer\n<< /Size {len(objetos)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF".encode("ascii"))
    return bytes(pdf)



def _combinar_pdf_rutina_con_maquina(pdf_rutina, archivo_maquina_bytes):
    """Une primero el PDF generado por KBeauty y luego el PDF de la maquina.

    Usa append cuando la version de pypdf lo soporta porque es mas rapido que
    recorrer pagina por pagina. Si no esta disponible, cae al metodo compatible.
    """
    if not archivo_maquina_bytes:
        return pdf_rutina
    try:
        from pypdf import PdfReader, PdfWriter

        salida = io.BytesIO()
        writer = PdfWriter()
        if hasattr(writer, "append"):
            writer.append(io.BytesIO(pdf_rutina))
            writer.append(io.BytesIO(archivo_maquina_bytes))
        else:
            for origen in (io.BytesIO(pdf_rutina), io.BytesIO(archivo_maquina_bytes)):
                reader = PdfReader(origen, strict=False)
                for pagina in reader.pages:
                    writer.add_page(pagina)
        writer.write(salida)
        return salida.getvalue()
    except Exception:
        respuesta_error("No se pudo unir el PDF de la maquina. Verifica que el archivo sea un PDF valido.", 400)

def _nombre_archivo_seguro(valor):
    base = re.sub(r"[^A-Za-z0-9_-]+", "_", _texto_pdf(valor).strip())[:48].strip("_")
    return base or "cliente"


def _html_base(titulo, contenido, usuario=None, mostrar_nav=True):
    nombre = ""
    if usuario:
        datos = usuario.get("datos_villar") or {}
        nombre = datos.get("nombre") or datos.get("correo") or str(usuario.get("villar_id"))
    sesion = f"<span>Sesion: <b>{escape(nombre)}</b></span> <a href='/kbeauty-data/logout'>Salir</a>" if usuario else ""
    nav_html = f"""
      <nav>
        <a href="/kbeauty-data/admin">Admin</a>
        <a href="/kbeauty-data/empleados">Empleados</a>
        <a href="/docs">Docs API</a>
        <div class="right">{sesion}</div>
      </nav>
    """ if mostrar_nav else ""
    return f"""
    <!doctype html>
    <html lang="es">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>{escape(titulo)}</title>
      <style>
        body {{ margin:0; font-family: Arial, sans-serif; background:#f3f6fb; color:#06142e; }}
        nav {{ padding:14px 24px; background:#fff; box-shadow:0 1px 8px rgba(255,42,65,.08); display:flex; gap:18px; align-items:center; }}
        nav a {{ color:#06142e; font-weight:700; }}
        .right {{ margin-left:auto; display:flex; gap:12px; align-items:center; font-size:14px; }}
        .wrap {{ max-width:1180px; margin:28px auto; padding:0 18px; }}
        .hero,.card {{ background:white; border-radius:22px; padding:26px; box-shadow:0 12px 35px rgba(20,36,66,.08); margin-bottom:24px; }}
        h1 {{ margin:0 0 10px; font-size:32px; }} h2 {{ margin-top:0; }}
        input,textarea,select {{ width:100%; box-sizing:border-box; padding:12px; border:1px solid #ccd6e3; border-radius:12px; font-size:15px; margin-top:6px; }}
        label {{ font-weight:700; display:block; margin-top:12px; }}
        button,.btn {{ display:inline-block; padding:12px 16px; border:0; border-radius:14px; background:linear-gradient(135deg,#f51d37,#ff6475); color:#fff; font-weight:800; cursor:pointer; text-decoration:none; margin-top:14px; box-shadow:0 12px 24px rgba(245,29,55,.22); }}
        table {{ width:100%; border-collapse:collapse; background:#fff; }} th,td {{ padding:12px; border-bottom:1px solid #e5ebf2; text-align:left; vertical-align:top; }}
        th {{ font-size:13px; color:#3a4b63; }} code {{ background:#eef3fa; padding:4px 7px; border-radius:8px; font-size:12px; }}
        .grid {{ display:grid; grid-template-columns:1fr 1fr; gap:20px; }} .ok {{ background:#e7fff2; color:#065f46; padding:12px; border-radius:14px; }}
        .warn {{ background:#fff7df; color:#755000; padding:12px; border-radius:14px; }} .small {{ font-size:13px; color:#53657d; }}
        .pill {{ display:inline-block; padding:4px 8px; border-radius:999px; background:#eef3fa; margin:2px; font-size:12px; }}
        @media(max-width:800px) {{ .grid {{ grid-template-columns:1fr; }} }}
      </style>
    </head>
    <body>
      {nav_html}
      <main class="wrap">{contenido}</main>
    </body>
    </html>
    """


def _usuario_web_o_redirect(request: Request, destino: str):
    token = request.cookies.get(COOKIE)
    usuario = usuario_desde_token_web(token) if token else None
    if not usuario:
        return None, _redirect_login_limpiando_sesion(destino)
    return usuario, None


def _usuario_web_o_bearer(request: Request, destino: str = "/kbeauty-data/empleados"):
    """Acepta sesion web KBEAUTY-DATA o token movil Authorization: Bearer.

    Las vistas web usan cookie, pero Flutter abre el PDF con token.
    Por eso estas rutas publicas de analisis presencial deben soportar ambos caminos.
    """
    token_cookie = request.cookies.get(COOKIE)
    usuario = usuario_desde_token_web(token_cookie) if token_cookie else None
    if usuario:
        return usuario, None

    autorizacion = request.headers.get("authorization") or request.headers.get("Authorization") or ""
    partes = autorizacion.split(None, 1)
    if len(partes) == 2 and partes[0].lower() == "bearer":
        usuario = usuario_desde_token_web(partes[1].strip())
        if usuario:
            return usuario, None

    return None, _redirect_login_limpiando_sesion(destino)


@router.get("/kbeauty-data/login")
def login_kbeauty_data(next: str = Query("/kbeauty-data/empleados")):
    return RedirectResponse(construir_url_login_sso(next), status_code=302)


@router.get("/kbeauty-data/logout")
def logout_kbeauty_data():
    respuesta = RedirectResponse("/kbeauty-data/login", status_code=302)
    respuesta.delete_cookie(COOKIE)
    return respuesta


@router.get("/kbeauty-data/sso/callback")
def callback_sso(request: Request):
    token = extraer_token_callback(request.query_params)
    if not token:
        token = intercambiar_codigo_sso(request.query_params.get("code"))
    if not token:
        return HTMLResponse(_html_base("SSO error", "<div class='card'><h1>No se recibio token de Villar.do</h1><p>Revisa el redirect_uri y la configuracion de la App Key.</p></div>"), status_code=400)
    usuario = usuario_desde_token_web(token)
    if not usuario:
        return _redirect_login_limpiando_sesion("/kbeauty-data/empleados")
    destino = request.query_params.get("estado") or request.query_params.get("state") or "/kbeauty-data/empleados"
    if not destino.startswith("/kbeauty-data/"):
        destino = "/kbeauty-data/empleados"
    respuesta = RedirectResponse(destino, status_code=302)
    respuesta.set_cookie(COOKIE, token, httponly=True, samesite="lax", secure=False, max_age=60 * 60 * 24 * 7)
    return respuesta


@router.get("/kbeauty-data/admin", response_class=HTMLResponse)
def vista_admin(request: Request, q: str = ""):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    if not usuario_tiene_rol(usuario, ROLES_ADMIN):
        return HTMLResponse(_html_base("Sin permiso", "<div class='card'><h1>Acceso denegado</h1><p>Tu usuario no tiene rol admin_kbeauty, admin, administrador o developer.</p></div>", usuario), status_code=403)
    roles = listar_roles()
    usuarios = listar_usuarios_kbeauty(q, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar"))
    filas_roles = "".join([f"<option value='{escape(r['codigo'])}'>{escape(r['codigo'])} - {escape(r['nombre'])}</option>" for r in roles])
    filas = "".join([
        f"""
        <tr>
          <td><b>{escape(u.get('villar_nombre') or 'Sin nombre')}</b><br><span class='small'>{escape(u.get('villar_correo') or 'Correo no disponible')}</span><br><span class='small'>{escape(u.get('villar_telefono') or '')}</span>{f"<br><span class='small'>Villar.do: {escape(u.get('villar_error'))}</span>" if u.get('villar_error') else ""}</td>
          <td><code>{escape(str(u.get('id')))}</code></td>
          <td><code>{escape(str(u.get('villar_id')))}</code></td>
          <td>{''.join([f"<span class='pill'>{escape(r.get('codigo',''))}</span>" for r in u.get('roles', [])])}</td>
          <td>{escape(u.get('tipo_piel') or '')}<br><span class='small'>{escape(u.get('condicion_principal') or '')}</span></td>
        </tr>
        """ for u in usuarios
    ])
    contenido = f"""
    <div class='hero'>
      <h1>KBEAUTY-DATA Admin</h1>
      <p>Protegido con SSO Villar.do. Vista temporal para crear/asignar roles.</p>
      <div class='ok'>Login activo con Villar.do usando VILLAR_DO_APP_KEY.</div>
      <p class='small'>Roles de tu sesion: {escape(', '.join(sorted(codigos_roles(usuario))))}</p>
    </div>
    <div class='grid'>
      <div class='card'>
        <h2>Crear rol</h2>
        <form method='post' action='/kbeauty-data/admin/roles/crear'>
          <label>Codigo</label><input name='codigo' value='kbeauty_data'>
          <label>Nombre</label><input name='nombre' value='Empleado KBEAUTY-DATA'>
          <label>Descripcion</label><textarea name='descripcion'>Permite subir analisis presenciales PDF de clientes</textarea>
          <button>Crear rol</button>
        </form>
      </div>
      <div class='card'>
        <h2>Asignar rol</h2>
        <form method='post' action='/kbeauty-data/admin/roles/asignar'>
          <label>Villar ID del usuario</label><input name='villar_id' placeholder='uuid del usuario'>
          <label>Rol</label><select name='codigo_rol'>{filas_roles}</select>
          <button>Asignar rol</button>
        </form>
      </div>
    </div>
    <div class='card'>
      <h2>Usuarios KBeauty + datos Villar.do</h2>
      <form method='get' action='/kbeauty-data/admin'>
        <label>Buscar por id o Villar ID</label><input name='q' value='{escape(q or '')}' placeholder='uuid'>
        <button>Buscar</button>
      </form>
      <table><thead><tr><th>Usuario Villar.do</th><th>ID KBeauty</th><th>Villar ID</th><th>Roles</th><th>Perfil</th></tr></thead><tbody>{filas}</tbody></table>
    </div>
    """
    return HTMLResponse(_html_base("KBEAUTY-DATA Admin", contenido, usuario))


@router.post("/kbeauty-data/admin/roles/crear")
def accion_crear_rol(request: Request, codigo: str = Form(...), nombre: str = Form(...), descripcion: str = Form("")):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    exigir_admin(usuario)
    crear_rol(codigo, nombre, descripcion)
    return RedirectResponse("/kbeauty-data/admin", status_code=303)


@router.post("/kbeauty-data/admin/roles/asignar")
def accion_asignar_rol(request: Request, villar_id: str = Form(...), codigo_rol: str = Form(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    exigir_admin(usuario)
    asignar_rol_a_villar_id(villar_id, codigo_rol)
    return RedirectResponse("/kbeauty-data/admin", status_code=303)


@router.get("/kbeauty-data/empleados", response_class=HTMLResponse)
def vista_empleados(request: Request):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    if not usuario_tiene_rol(usuario, ROLES_EMPLEADO):
        return HTMLResponse(_html_base("Sin permiso", "<div class='card'><h1>Acceso denegado</h1><p>Tu usuario no tiene rol kbeauty_data.</p></div>", usuario), status_code=403)

    rutinas_no_app_json = json.dumps(listar_rutinas(), ensure_ascii=False)
    villar_base = (VILLAR_DO_API_URL or "").strip().rstrip("/")
    villar_codigo_app = (VILLAR_DO_CLIENT_ID or "").strip().strip("/")
    enlace_invitacion_villar = f"{villar_base}/i/{villar_codigo_app}" if villar_base and villar_codigo_app else ""
    enlace_invitacion_villar_html = escape(enlace_invitacion_villar, quote=True)

    contenido = """
    <style>
      body {
        background:
          radial-gradient(circle at 20% 8%, rgba(255, 103, 119, .24), transparent 34%),
          radial-gradient(circle at 82% 24%, rgba(255, 213, 218, .58), transparent 30%),
          linear-gradient(180deg, #fff0f3 0%, #fff7f8 44%, #ffecef 100%) !important;
      }
      main.wrap { max-width:none; margin:0; padding:0; }
      .kd-shell {
        min-height:100vh;
        width:min(1180px, calc(100% - 44px));
        margin:0 auto;
        padding:28px 0 54px;
        background:transparent;
      }
      .app-top { display:flex; align-items:center; justify-content:space-between; margin-bottom:22px; }
      .app-brand { display:flex; gap:13px; align-items:center; }
      .app-brand b { display:block; font-size:22px; color:#28262d; letter-spacing:-.4px; }
      .app-brand small { display:block; color:#7d7680; font-weight:700; margin-top:2px; }
      .brand-icon, .logout-round {
        width:48px; height:48px; border-radius:19px; display:grid; place-items:center;
        background:#ffe0e5; color:#f51d37; font-weight:900; text-decoration:none;
        box-shadow:0 12px 26px rgba(245,29,55,.10);
      }
      .logout-round { background:#ffd8d2; color:#2b2a31; font-size:23px; }
      .kd-banner {
        position:relative;
        overflow:hidden;
        background:linear-gradient(135deg,#f51d37 0%, #ff4358 52%, #ff7480 100%);
        color:#fff; border-radius:34px; padding:36px 34px;
        box-shadow:0 28px 62px rgba(245,29,55,.27);
        margin-bottom:32px;
      }
      .kd-banner:after {
        content:""; position:absolute; width:220px; height:220px; border-radius:999px;
        right:-80px; top:-90px; background:rgba(255,255,255,.18);
      }
      .kd-banner h1 { margin:0; font-size:34px; line-height:1.05; letter-spacing:-.9px; }
      .kd-banner p { margin:13px 0 0; font-weight:800; line-height:1.45; color:#fff; max-width:560px; }
      .kd-content {
        display:grid;
        grid-template-columns:minmax(300px, 420px) minmax(0, 1fr);
        gap:24px;
        align-items:start;
      }
      .search-panel, .profile-card, .panel-card, .empty-state {
        background:rgba(255,255,255,.74);
        backdrop-filter:blur(18px);
        border:1px solid rgba(255,255,255,.82);
        box-shadow:0 22px 55px rgba(245,29,55,.10);
        border-radius:34px;
      }
      .search-panel { padding:24px; position:sticky; top:22px; }
      .upload-panel { margin-top:20px; padding-top:20px; border-top:1px solid rgba(255, 224, 229, .95); }
      .upload-panel h2 { margin:0; color:#28262d; letter-spacing:-.4px; }
      .upload-panel .upload-hint { margin:7px 0 14px; color:#7b7680; font-size:13px; font-weight:700; line-height:1.4; }
      .upload-panel.disabled { opacity:.58; }
      .upload-panel.disabled .drop-zone { cursor:not-allowed; }
      .upload-panel.disabled button[type=submit] { opacity:.55; cursor:not-allowed; box-shadow:none; }
      .modo-panel { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin:18px 0 8px; }
      .modo-btn {
        border:1px solid #ffe0e5; border-radius:22px; padding:14px 12px; background:#fff;
        color:#2b2a31; font-weight:950; cursor:pointer; box-shadow:0 12px 26px rgba(245,29,55,.08);
        text-align:left; transition:.15s;
      }
      .modo-btn span { display:block; font-size:20px; margin-bottom:4px; }
      .modo-btn small { display:block; color:#7d7680; font-weight:800; line-height:1.25; }
      .modo-btn.active { background:linear-gradient(135deg,#f51d37,#ff6475); color:#fff; border-color:#ff6475; transform:translateY(-1px); }
      .modo-btn.active small { color:#fff; opacity:.92; }
      .invite-card {
        position:relative; overflow:hidden; margin:16px 0 6px; padding:16px; border-radius:26px;
        background:linear-gradient(135deg,#fff 0%, #fff4f7 58%, #ffe7ec 100%);
        border:1px solid rgba(255, 196, 207, .95); box-shadow:0 18px 42px rgba(245,29,55,.10);
      }
      .invite-card:before {
        content:""; position:absolute; right:-42px; top:-54px; width:130px; height:130px; border-radius:999px;
        background:radial-gradient(circle, rgba(245,29,55,.20), rgba(245,29,55,0) 68%);
      }
      .invite-head { display:flex; gap:12px; align-items:flex-start; position:relative; z-index:1; }
      .invite-icon {
        width:42px; height:42px; border-radius:17px; display:grid; place-items:center; flex:0 0 auto;
        background:linear-gradient(135deg,#f51d37,#ff7480); color:#fff; font-size:21px;
        box-shadow:0 12px 24px rgba(245,29,55,.18);
      }
      .invite-title { margin:0; color:#28262d; font-size:16px; letter-spacing:-.2px; }
      .invite-text { margin:4px 0 0; color:#7b7680; font-size:12px; font-weight:800; line-height:1.35; }
      .invite-copy-row { display:flex; gap:9px; align-items:center; margin-top:13px; position:relative; z-index:1; }
      .invite-input {
        min-width:0; flex:1; height:42px; padding:0 13px; border-radius:18px; border:1px solid #ffe0e5;
        background:#fff; color:#514b55; font-size:12px; font-weight:850; box-shadow:inset 0 1px 0 rgba(255,255,255,.8);
      }
      .copy-btn {
        border:0 !important; height:42px; padding:0 15px !important; border-radius:18px !important;
        background:linear-gradient(135deg,#2b2a31,#57515c) !important; color:#fff !important;
        font-weight:950; cursor:pointer; white-space:nowrap; box-shadow:0 12px 22px rgba(43,42,49,.16) !important;
      }
      .copy-btn.copied { background:linear-gradient(135deg,#12a999,#46d5c4) !important; }
      .invite-empty { margin-top:12px; position:relative; z-index:1; color:#a36b75; font-size:12px; font-weight:850; line-height:1.35; }
      .rutina-rapida-panel { margin-top:20px; padding-top:20px; border-top:1px solid rgba(255, 224, 229, .95); }
      .rutina-rapida-panel h2 { margin:0; color:#28262d; letter-spacing:-.4px; }
      .rutina-rapida-panel .upload-hint { margin:7px 0 14px; color:#7b7680; font-size:13px; font-weight:700; line-height:1.4; }

      .pdf-maquina-box { margin-top:14px; padding:14px; border:1px dashed #ff9bac; border-radius:22px; background:#fff8fa; }
      .pdf-maquina-box input[type=file] { width:100%; padding:12px; border-radius:18px; border:1px solid #ffe0e5; background:#fff; font-weight:800; color:#6b626d; }
      .pdf-maquina-box .small { display:block; margin-top:8px; color:#8a7f88; font-size:12px; font-weight:750; line-height:1.35; }
      .rutina-select { background:#fff; border:1px solid #ffe0e5; border-radius:22px; margin-top:10px; }
      .rutina-preview { margin-top:12px; padding:14px; border-radius:22px; background:#fff6f8; color:#6b626d; font-size:13px; font-weight:800; line-height:1.45; }
      .cliente-sin-app-box { display:grid; gap:10px; margin:12px 0 6px; }
      .cliente-sin-app-box label { margin-top:4px; color:#3a333b; }
      .cliente-sin-app-box input { background:#fff; border:1px solid #ffe0e5; border-radius:22px; }
      .download-btn { background:linear-gradient(135deg,#2b2a31,#57515c); box-shadow:0 12px 24px rgba(43,42,49,.18); }
      .download-btn:disabled, .download-btn.disabled {
        background:#d9d5dc !important; color:#8c8490 !important; cursor:not-allowed !important;
        box-shadow:none !important; opacity:1 !important; border:1px solid #d9d5dc !important;
        filter:saturate(.35);
      }
      .download-btn.ready { background:linear-gradient(135deg,#2b2a31,#57515c) !important; color:#fff !important; box-shadow:0 12px 24px rgba(43,42,49,.18) !important; filter:none; }
      .form-missing-hint { margin-top:10px; padding:11px 13px; border-radius:18px; background:#f4f1f5; color:#817987; font-size:12px; font-weight:850; line-height:1.35; }
      .client-summary { background:#fff; border:1px solid #ffe0e5; border-radius:26px; padding:16px; display:grid; gap:4px; }
      .client-summary b { color:#28262d; font-size:18px; }
      .quick-routine { display:grid; gap:18px; }
      .routine-hero {
        background:linear-gradient(135deg,#fff,#fff4f6); border:1px solid #ffe0e5;
        border-radius:34px; padding:24px; box-shadow:0 22px 55px rgba(245,29,55,.10);
      }
      .routine-hero h2 { margin:0; color:#28262d; font-size:28px; letter-spacing:-.7px; }
      .routine-meta { display:flex; flex-wrap:wrap; gap:8px; margin-top:14px; }
      .routine-block { background:rgba(255,255,255,.82); border:1px solid #ffe0e5; border-radius:30px; padding:20px; box-shadow:0 18px 42px rgba(245,29,55,.08); }
      .routine-block h3 { margin:0 0 14px; color:#28262d; font-size:21px; }
      .product-grid { display:grid; gap:12px; }
      .product-card { background:#fff; border:1px solid #fff0f3; border-radius:22px; padding:15px; }
      .product-card b { color:#28262d; font-size:15px; }
      .product-card .small { margin-top:5px; line-height:1.45; }
      .product-desc { margin-top:8px; color:#615b66; font-size:13px; font-weight:700; line-height:1.45; }
      .kd-hero { text-align:left; padding:0; }
      .kd-title { font-size:30px; font-weight:950; margin:0; letter-spacing:-.9px; color:#28262d; }
      .kd-subtitle { color:#7b7680; margin:8px 0 0; line-height:1.45; font-weight:700; }
      .search-wrap { margin:22px 0 0; position:relative; }
      .search-box {
        display:flex; align-items:center; gap:12px; background:#fff; border:1px solid #ffe0e5;
        box-shadow:0 18px 38px rgba(255,42,65,.11); border-radius:25px; padding:10px 16px;
      }
      .search-icon { font-size:22px; opacity:.7; }
      #buscadorCliente { border:0; outline:none; margin:0; padding:15px 8px; font-size:16px; border-radius:20px; color:#2b2a31; background:transparent; }
      #buscadorCliente::placeholder { color:#8f8994; }
      .suggestions {
        position:absolute; left:0; right:0; top:74px; background:#fff; border:1px solid #ffe0e5;
        border-radius:26px; box-shadow:0 24px 62px rgba(245,29,55,.18); overflow:hidden; z-index:10; display:none;
      }
      .suggestion { padding:15px 18px; cursor:pointer; display:grid; grid-template-columns:1fr auto; gap:14px; border-bottom:1px solid #fff0f3; }
      .suggestion:hover { background:#fff3f5; }
      .suggestion:last-child { border-bottom:0; }
      .s-name { font-weight:950; color:#2b2a31; }
      .s-meta { color:#655f69; font-size:13px; margin-top:3px; word-break:break-word; }
      .s-id { color:#f51d37; font-size:12px; background:#ffecef; border-radius:999px; padding:7px 10px; align-self:center; font-weight:950; }
      .work-area { min-height:360px; }
      .empty-state { text-align:center; color:#7b7882; padding:42px 22px; }
      .empty-state b { display:block; color:#28262d; font-size:22px; margin-bottom:8px; }
      .client-layout { display:grid; grid-template-columns:minmax(280px,.82fr) minmax(0,1.18fr); gap:18px; align-items:start; margin-top:0; display:none; }
      .profile-card, .panel-card { padding:22px; }
      .avatar {
        width:66px; height:66px; border-radius:24px; display:grid; place-items:center;
        background:#ffe2e7; color:#f51d37; font-size:26px; font-weight:950;
        box-shadow:0 14px 30px rgba(245,29,55,.16);
      }
      .profile-top { display:flex; gap:16px; align-items:center; margin-bottom:18px; }
      .client-name { margin:0; font-size:23px; line-height:1.15; color:#28262d; letter-spacing:-.5px; }
      .client-email { color:#68616d; margin-top:5px; word-break:break-word; font-weight:700; }
      .info-line { padding:13px 0; border-top:1px solid #fff0f3; display:flex; justify-content:space-between; gap:14px; }
      .info-line span:first-child { color:#7b7680; font-weight:700; }
      .info-line b { text-align:right; color:#28262d; word-break:break-word; }
      .tabs-title { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:16px; }
      .tabs-title h2 { margin:0; color:#28262d; letter-spacing:-.4px; }
      .analysis-list { display:grid; gap:12px; margin-bottom:24px; }
      .analysis-item { border:1px solid #fff0f3; border-radius:22px; padding:15px; display:flex; justify-content:space-between; gap:12px; align-items:center; background:#fff; }
      .tag { display:inline-flex; align-items:center; border-radius:999px; padding:7px 11px; font-size:12px; font-weight:950; background:#ffecef; color:#f51d37; white-space:nowrap; }
      .tag.presencial { background:#ddfaf4; color:#12a999; }
      .drop-zone {
        width:100%; min-height:154px; box-sizing:border-box; display:flex; flex-direction:column;
        align-items:center; justify-content:center; gap:6px; border:2px dashed #ffd1dc;
        border-radius:30px; padding:28px 22px; text-align:center; background:#fffafb;
        transition:.18s ease; cursor:pointer; color:#847d87; margin-top:8px;
      }
      .drop-zone:hover { border-color:#ff9db0; background:#fff5f7; box-shadow:0 18px 42px rgba(245,29,55,.08); transform:translateY(-1px); }
      .drop-zone.drag { border-color:#f51d37; background:#fff0f3; transform:scale(1.01); box-shadow:0 20px 46px rgba(245,29,55,.12); }
      .drop-zone input { display:none; }
      .drop-zone b { color:#7a747d; font-size:20px; letter-spacing:-.25px; }
      .drop-zone .small { margin:0; color:#9ca3b6; font-size:14px; font-weight:800; }
      .drop-icon { width:54px; height:54px; margin-bottom:2px; position:relative; display:block; }
      .drop-icon::before {
        content:''; position:absolute; left:12px; top:5px; width:30px; height:38px; border:4px solid #77737a;
        border-radius:2px; background:#fff; box-sizing:border-box;
      }
      .drop-icon::after {
        content:''; position:absolute; left:20px; top:17px; width:16px; height:3px; background:#c4c4c7;
        box-shadow:0 7px 0 #d7d7da, 0 14px 0 #e1e1e4;
      }
      .drop-zone.has-file { border-color:#f51d37; background:#fff4f6; }
      .upload-row { display:flex; gap:12px; align-items:center; justify-content:center; flex-wrap:wrap; margin-top:16px; }
      button,.secondary-btn {
        border-radius:999px !important;
        padding:13px 18px !important;
      }
      .secondary-btn { background:#fff0f3 !important; color:#f51d37 !important; box-shadow:none !important; }
      .status { margin-top:14px; color:#6f6872; font-size:14px; font-weight:700; }
      .hidden { display:none !important; }
      .upload-splash { position:fixed; inset:0; z-index:9999; display:none; align-items:center; justify-content:center; padding:24px; background:rgba(255,240,243,.82); backdrop-filter:blur(14px); }
      .upload-splash.active { display:flex; }
      .upload-box { width:min(420px, calc(100% - 32px)); text-align:center; background:#fff; border-radius:34px; padding:34px 28px; box-shadow:0 32px 88px rgba(245,29,55,.22); border:1px solid #ffe0e5; }
      .upload-loader { width:72px; height:72px; border-radius:999px; margin:0 auto 18px; border:7px solid #ffe0e5; border-top-color:#f51d37; animation:girar .82s linear infinite; }
      .upload-box h2 { margin:0; color:#28262d; font-size:24px; }
      .upload-box p { color:#7b7680; font-weight:700; margin:10px 0 0; line-height:1.45; }
      @keyframes girar { to { transform:rotate(360deg); } }
      label { color:#28262d; }
      textarea { background:#fff; border:1px solid #ffe0e5; border-radius:22px; }
      @media(max-width:900px) {
        .kd-shell { width:min(430px, calc(100% - 26px)); padding:18px 0 36px; }
        .kd-content { grid-template-columns:1fr; }
        .search-panel { position:static; }
        .client-layout { grid-template-columns:1fr; }
        .kd-banner { padding:28px 22px; border-radius:30px; }
        .kd-banner h1 { font-size:29px; }
      }
    </style>

    <section class='kd-shell'>
      <div class='app-top'>
        <div class='app-brand'><span class='brand-icon'>☘</span><div><b>KBeauty IA</b><small>Panel empleados</small></div></div>
        <a class='logout-round' href='/kbeauty-data/logout' title='Salir'>↪</a>
      </div>
      <div class='kd-banner'>
        <h1>Hola, equipo luminoso</h1>
        <p>Busca el cliente y sube su análisis presencial en PDF.</p>
      </div>
      <div class='kd-content'>
        <aside class='search-panel'>
          <div class='kd-hero'>
            <h1 class='kd-title'>Tipo de atención</h1>
            <p class='kd-subtitle'>Elige si el cliente tiene app o si solo necesita una recomendación rápida de rutina.</p>
            <div class='modo-panel'>
              <button id='modoConApp' type='button' class='modo-btn active'><span>📱</span>Con app<small>Buscar cliente y subir PDF.</small></button>
              <button id='modoSinApp' type='button' class='modo-btn'><span>✨</span>Sin app<small>Elegir rutina del JSON.</small></button>
            </div>
            <div class='invite-card'>
              <div class='invite-head'>
                <span class='invite-icon'>🔗</span>
                <div>
                  <h2 class='invite-title'>Enlace de invitación Villar.do</h2>
                  <p class='invite-text'>Cópialo para enviarlo al cliente y que entre directo a la invitación de KBeauty IA.</p>
                </div>
              </div>
              <div id='inviteCopyBox' class='invite-copy-row'>
                <input id='enlaceInvitacionVillar' class='invite-input' value='__ENLACE_INVITACION_VILLAR__' readonly>
                <button id='copiarEnlaceInvitacion' type='button' class='copy-btn'>Copiar</button>
              </div>
              <div id='inviteEmptyMsg' class='invite-empty hidden'>Configura VILLAR_DO_API_URL y VILLAR_DO_CLIENT_ID en el .env para mostrar el enlace.</div>
            </div>
          </div>

          <div id='panelConApp'>
            <div class='kd-hero'>
              <h1 class='kd-title'>Buscar cliente</h1>
              <p class='kd-subtitle'>Escribe correo, nombre o Villar ID. Aparecerán coincidencias al instante.</p>
              <div class='search-wrap'>
                <div class='search-box'>
                  <span class='search-icon'>🔎</span>
                  <input id='buscadorCliente' autocomplete='off' placeholder='Correo, nombre o Villar ID'>
                </div>
                <div id='sugerencias' class='suggestions'></div>
              </div>
            </div>
          </div>

          <div id='panelSinApp' class='rutina-rapida-panel hidden'>
            <h2>Rutina rápida</h2>
            <p class='upload-hint'>No usa IA, no guarda análisis y no requiere app. El empleado selecciona una rutina existente del JSON.</p>
            <div class='cliente-sin-app-box'>
              <label>Nombre del cliente</label>
              <input id='clienteSinAppNombre' type='text' autocomplete='off' placeholder='Ej: María Pérez'>
              <label>Número de teléfono</label>
              <input id='clienteSinAppTelefono' type='tel' autocomplete='off' placeholder='Ej: 809-000-0000'>
            </div>
            <div class='pdf-maquina-box'>
              <label>PDF del análisis de la máquina <span class='small'>(obligatorio)</span></label>
              <label id='dropZoneMaquina' class='drop-zone'>
                <input id='pdfMaquinaSinApp' type='file' accept='application/pdf,.pdf'>
                <div class='drop-icon'></div>
                <b>Arrastra el PDF aquí</b>
                <p class='small'>o toca para seleccionarlo. Solo se acepta PDF.</p>
                <div id='nombreArchivoMaquina' class='status'></div>
              </label>
              <span class='small'>Este PDF es obligatorio. El sistema descargará un solo PDF: primero la rutina generada por KBeauty y después el PDF original de la máquina.</span>
            </div>
            <label>Seleccionar rutina</label>
            <select id='selectorRutinaRapida' class='rutina-select'>
              <option value=''>Selecciona una rutina...</option>
            </select>
            <div id='previewRutinaRapida' class='rutina-preview'>Elige una rutina para ver tipo de piel, condición y productos.</div>
            <div class='upload-row'>
              <button id='botonVerRutinaRapida' type='button'>Ver rutina</button>
              <button id='botonDescargarRutinaPdf' type='button' class='download-btn' disabled>Descargar PDF</button>
            </div>
            <div id='hintPdfSinApp' class='form-missing-hint'>Completa nombre, teléfono, rutina y sube el PDF de la máquina para activar la descarga.</div>
          </div>

          <div id='uploadPanel' class='upload-panel disabled'>
            <h2>Subir PDF presencial</h2>
            <p class='upload-hint' id='uploadHint'>Primero selecciona un cliente para activar la subida.</p>
            <form id='formPdf'>
              <input type='hidden' id='villarIdSeleccionado' name='villar_id'>
              <input type='hidden' id='perfilIdSeleccionado' name='perfil_id'>
              <label>Notas internas opcionales</label>
              <textarea id='notasPdf' name='notas' placeholder='Ej: análisis realizado en cabina, sucursal, observaciones...'></textarea>
              <label id='dropZone' class='drop-zone'>
                <input id='archivoPdf' name='archivo' type='file' accept='application/pdf'>
                <div class='drop-icon'></div>
                <b>Arrastra el PDF aquí</b>
                <p class='small'>o toca para seleccionarlo. Solo se acepta PDF.</p>
                <div id='nombreArchivo' class='status'></div>
              </label>
              <div class='upload-row'>
                <button id='botonSubirPdf' type='submit' disabled>Subir PDF</button>
                <button type='button' id='limpiarSeleccion' class='secondary-btn'>Limpiar</button>
              </div>
              <div id='estadoUpload' class='status'></div>
            </form>
          </div>
        </aside>

        <section class='work-area'>
          <div id='estadoInicial' class='empty-state'><b>Selecciona una opción</b>Usa cliente con app para subir PDF o cliente sin app para mostrar una rutina rápida.</div>

          <section id='clienteLayout' class='client-layout'>
        <aside class='profile-card'>
          <div class='profile-top'>
            <div id='clienteAvatar' class='avatar'>K</div>
            <div>
              <h2 id='clienteNombre' class='client-name'>Cliente</h2>
              <div id='clienteCorreo' class='client-email'>Correo no disponible</div>
            </div>
          </div>
          <div class='info-line'><span>Villar ID</span><b id='clienteVillarId'>-</b></div>
          <div class='info-line'><span>ID KBeauty</span><b id='clienteKbeautyId'>-</b></div>
          <div class='info-line'><span>Tipo de piel</span><b id='clienteTipoPiel'>-</b></div>
          <div class='info-line'><span>Condición</span><b id='clienteCondicion'>-</b></div>
          <div class='info-line'><span>Sensibilidad</span><b id='clienteSensibilidad'>-</b></div>
        </aside>

        <div class='panel-card'>
          <div class='tabs-title'>
            <h2>Análisis del cliente</h2>
            <span id='contadorAnalisis' class='tag'>0 análisis</span>
          </div>
          <div id='listaAnalisis' class='analysis-list'></div>

        </div>
          </section>

          <section id='rutinaRapidaResultado' class='quick-routine hidden'></section>
        </section>
      </div>
    </section>

    <div id='uploadSplash' class='upload-splash' aria-hidden='true'>
      <div class='upload-box'>
        <div class='upload-loader'></div>
        <h2 id='splashTitulo'>Subiendo y analizando PDF</h2>
        <p id='splashTexto'>Estamos guardando el archivo y extrayendo los datos del análisis presencial. No cierres esta pantalla.</p>
      </div>
    </div>

    <script>
      const input = document.getElementById('buscadorCliente');
      const sugerencias = document.getElementById('sugerencias');
      const layout = document.getElementById('clienteLayout');
      const estadoInicial = document.getElementById('estadoInicial');
      const dropZone = document.getElementById('dropZone');
      const archivoPdf = document.getElementById('archivoPdf');
      const nombreArchivo = document.getElementById('nombreArchivo');
      const estadoUpload = document.getElementById('estadoUpload');
      const uploadPanel = document.getElementById('uploadPanel');
      const uploadHint = document.getElementById('uploadHint');
      const uploadSplash = document.getElementById('uploadSplash');
      const splashTitulo = document.getElementById('splashTitulo');
      const splashTexto = document.getElementById('splashTexto');
      const botonSubirPdf = document.getElementById('botonSubirPdf');
      const modoConApp = document.getElementById('modoConApp');
      const modoSinApp = document.getElementById('modoSinApp');
      const panelConApp = document.getElementById('panelConApp');
      const panelSinApp = document.getElementById('panelSinApp');
      const selectorRutinaRapida = document.getElementById('selectorRutinaRapida');
      const previewRutinaRapida = document.getElementById('previewRutinaRapida');
      const botonVerRutinaRapida = document.getElementById('botonVerRutinaRapida');
      const botonDescargarRutinaPdf = document.getElementById('botonDescargarRutinaPdf');
      const hintPdfSinApp = document.getElementById('hintPdfSinApp');
      const pdfMaquinaSinApp = document.getElementById('pdfMaquinaSinApp');
      const clienteSinAppNombre = document.getElementById('clienteSinAppNombre');
      const clienteSinAppTelefono = document.getElementById('clienteSinAppTelefono');
      const rutinaRapidaResultado = document.getElementById('rutinaRapidaResultado');
      const RUTINAS_NO_APP = __RUTINAS_NO_APP_JSON__;
      let timer = null;
      let clienteActual = null;
      cargarRutinasRapidas();
      actualizarEstadoUploadPorCliente();
      configurarCopiarInvitacion();

      function configurarCopiarInvitacion() {
        const enlace = enlaceInvitacionVillar ? enlaceInvitacionVillar.value.trim() : '';
        if (!enlace) {
          if (inviteCopyBox) inviteCopyBox.classList.add('hidden');
          if (inviteEmptyMsg) inviteEmptyMsg.classList.remove('hidden');
          return;
        }
        if (!copiarEnlaceInvitacion) return;
        copiarEnlaceInvitacion.addEventListener('click', async () => {
          try {
            if (navigator.clipboard && window.isSecureContext) {
              await navigator.clipboard.writeText(enlace);
            } else {
              enlaceInvitacionVillar.focus();
              enlaceInvitacionVillar.select();
              document.execCommand('copy');
            }
            copiarEnlaceInvitacion.textContent = 'Copiado';
            copiarEnlaceInvitacion.classList.add('copied');
            setTimeout(() => {
              copiarEnlaceInvitacion.textContent = 'Copiar';
              copiarEnlaceInvitacion.classList.remove('copied');
            }, 1600);
          } catch (e) {
            enlaceInvitacionVillar.focus();
            enlaceInvitacionVillar.select();
            alert('No se pudo copiar automáticamente. El enlace quedó seleccionado para copiarlo manualmente.');
          }
        });
      }

      function texto(v, fallback='-') { return v === null || v === undefined || v === '' ? fallback : v; }
      function esc(v) { return texto(v, '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch])); }
      function iniciales(nombre) { return (nombre || 'K').split(' ').map(x => x[0]).join('').slice(0,2).toUpperCase(); }
      function fechaBonita(valor) {
        if (!valor) return '';
        const d = new Date(valor);
        if (Number.isNaN(d.getTime())) return valor;
        return d.toLocaleString();
      }

      function cargarRutinasRapidas() {
        RUTINAS_NO_APP.forEach((rutina, i) => {
          const opt = document.createElement('option');
          opt.value = String(i);
          opt.textContent = `${rutina.nombre || 'Rutina'} · ${rutina.tipo_piel || 'piel'} · ${rutina.condicion || 'condición'}`;
          selectorRutinaRapida.appendChild(opt);
        });
      }

      function cambiarModo(modo) {
        const sinApp = modo === 'sin_app';
        modoConApp.classList.toggle('active', !sinApp);
        modoSinApp.classList.toggle('active', sinApp);
        panelConApp.classList.toggle('hidden', sinApp);
        panelSinApp.classList.toggle('hidden', !sinApp);
        uploadPanel.classList.toggle('hidden', sinApp);
        layout.style.display = 'none';
        rutinaRapidaResultado.classList.add('hidden');
        estadoInicial.classList.remove('hidden');
        estadoInicial.innerHTML = sinApp
          ? `<b>Cliente sin app</b>Selecciona una rutina del catálogo para mostrar la recomendación completa.`
          : `<b>Selecciona un cliente</b>Su perfil, análisis y subida de PDF aparecerán aquí.`;
      }

      function obtenerRutinaSeleccionada() {
        const i = parseInt(selectorRutinaRapida.value, 10);
        if (Number.isNaN(i)) return null;
        return RUTINAS_NO_APP[i] || null;
      }

      function productosPorMomento(rutina, momento) {
        const bloques = rutina.rutina || {};
        if (momento === 'dia') {
          return [...(bloques['mañana'] || []), ...(bloques['día'] || []), ...(bloques['dia'] || [])];
        }
        return bloques['noche'] || [];
      }

      function descripcionProducto(producto, momento) {
        const d = producto.descripcion_rutina || {};
        if (momento === 'dia') return d['día'] || d['dia'] || d['mañana'] || d['manana'] || '';
        return d['noche'] || d['día'] || d['dia'] || '';
      }

      function renderProductos(productos, momento) {
        if (!productos.length) return `<div class='analysis-item'><div><b>No hay productos configurados</b><div class='small'>Esta rutina no tiene pasos para este momento.</div></div></div>`;
        return productos.map((p, idx) => {
          const paso = (p.uso && p.uso.paso_rutina) ? p.uso.paso_rutina : (p.categoria || 'producto');
          const desc = descripcionProducto(p, momento);
          return `<div class='product-card'>
            <b>${idx + 1}. ${esc(p.nombre_producto || 'Producto')}</b>
            <div class='small'>${esc(paso)}${p.id_odoo ? ` · ID Odoo: ${esc(String(p.id_odoo))}` : ''}${p.frecuencia ? ` · ${esc(p.frecuencia)}` : ''}</div>
            ${desc ? `<div class='product-desc'>${esc(desc)}</div>` : ''}
          </div>`;
        }).join('');
      }

      function datosClienteSinApp() {
        return {
          nombre: (clienteSinAppNombre.value || '').trim(),
          telefono: (clienteSinAppTelefono.value || '').trim(),
        };
      }

      function validarClienteSinApp() {
        const datos = datosClienteSinApp();
        if (!datos.nombre) { alert('Escribe el nombre del cliente.'); clienteSinAppNombre.focus(); return null; }
        if (!datos.telefono) { alert('Escribe el número de teléfono del cliente.'); clienteSinAppTelefono.focus(); return null; }
        return datos;
      }

      function hayPdfMaquinaValido() {
        const file = pdfMaquinaSinApp && pdfMaquinaSinApp.files ? pdfMaquinaSinApp.files[0] : null;
        if (!file) return false;
        return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
      }

      function formularioSinAppCompleto() {
        const datos = datosClienteSinApp();
        return !!datos.nombre && !!datos.telefono && !!obtenerRutinaSeleccionada() && hayPdfMaquinaValido();
      }

      function actualizarBotonPdfSinApp() {
        const datos = datosClienteSinApp();
        const faltantes = [];
        if (!datos.nombre) faltantes.push('nombre');
        if (!datos.telefono) faltantes.push('teléfono');
        if (!obtenerRutinaSeleccionada()) faltantes.push('rutina');
        if (!hayPdfMaquinaValido()) faltantes.push('PDF de la máquina');
        const completo = faltantes.length === 0;
        botonDescargarRutinaPdf.disabled = !completo;
        botonDescargarRutinaPdf.classList.toggle('ready', completo);
        botonDescargarRutinaPdf.classList.toggle('disabled', !completo);
        botonDescargarRutinaPdf.title = completo
          ? 'Descargar PDF combinado'
          : `Falta completar: ${faltantes.join(', ')}.`;
        if (hintPdfSinApp) {
          hintPdfSinApp.textContent = completo
            ? 'Todo listo. Puedes generar el PDF combinado.'
            : `Para generar el PDF falta: ${faltantes.join(', ')}.`;
        }
      }

      function mostrarSplash(titulo, texto) {
        if (splashTitulo) splashTitulo.textContent = titulo;
        if (splashTexto) splashTexto.textContent = texto;
        uploadSplash.classList.add('active');
        uploadSplash.setAttribute('aria-hidden', 'false');
      }

      function ocultarSplash() {
        uploadSplash.classList.remove('active');
        uploadSplash.setAttribute('aria-hidden', 'true');
      }

      function pintarRutinaRapida(rutina) {
        const dia = productosPorMomento(rutina, 'dia');
        const noche = productosPorMomento(rutina, 'noche');
        const datosCliente = datosClienteSinApp();
        estadoInicial.classList.add('hidden');
        layout.style.display = 'none';
        rutinaRapidaResultado.classList.remove('hidden');
        rutinaRapidaResultado.innerHTML = `
          <div class='routine-hero'>
            <div class='client-summary'>
              <small>Cliente sin app</small>
              <b>${esc(datosCliente.nombre || 'Cliente')}</b>
              <span class='small'>Teléfono: ${esc(datosCliente.telefono || 'No indicado')}</span>
            </div>
            <h2 style='margin-top:18px'>${esc(rutina.nombre || 'Rutina seleccionada')}</h2>
            <p class='kd-subtitle'>Recomendación manual seleccionada por el empleado desde el JSON de rutinas. No usa IA y no se guarda en la cuenta de ningún cliente.</p>
            <div class='routine-meta'>
              <span class='tag'>Tipo de piel: ${esc(rutina.tipo_piel || 'N/D')}</span>
              <span class='tag presencial'>Condición: ${esc(rutina.condicion || 'N/D')}</span>
              <span class='tag'>${dia.length + noche.length} productos</span>
            </div>
          </div>
          <div class='routine-block'>
            <h3>Rutina de Día</h3>
            <div class='product-grid'>${renderProductos(dia, 'dia')}</div>
          </div>
          <div class='routine-block'>
            <h3>Rutina de Noche</h3>
            <div class='product-grid'>${renderProductos(noche, 'noche')}</div>
          </div>`;
      }

      modoConApp.addEventListener('click', () => cambiarModo('con_app'));
      modoSinApp.addEventListener('click', () => cambiarModo('sin_app'));
      selectorRutinaRapida.addEventListener('change', () => {
        const rutina = obtenerRutinaSeleccionada();
        previewRutinaRapida.textContent = rutina
          ? `${rutina.nombre || 'Rutina'} · Tipo de piel: ${rutina.tipo_piel || 'N/D'} · Condición: ${rutina.condicion || 'N/D'}`
          : 'Elige una rutina para ver tipo de piel, condición y productos.';
        actualizarBotonPdfSinApp();
      });
      clienteSinAppNombre.addEventListener('input', actualizarBotonPdfSinApp);
      clienteSinAppTelefono.addEventListener('input', actualizarBotonPdfSinApp);
      actualizarBotonPdfSinApp();

      botonVerRutinaRapida.addEventListener('click', () => {
        const rutina = obtenerRutinaSeleccionada();
        if (!rutina) { alert('Selecciona una rutina primero.'); return; }
        if (!validarClienteSinApp()) return;
        pintarRutinaRapida(rutina);
      });

      botonDescargarRutinaPdf.addEventListener('click', async () => {
        const rutina = obtenerRutinaSeleccionada();
        const datos = validarClienteSinApp();
        if (!rutina || !datos) { if (!rutina) alert('Selecciona una rutina primero.'); return; }
        if (!hayPdfMaquinaValido()) {
          alert('Sube el PDF del análisis de la máquina para poder generar el PDF combinado.');
          if (pdfMaquinaSinApp) pdfMaquinaSinApp.focus();
          actualizarBotonPdfSinApp();
          return;
        }
        const form = new FormData();
        form.append('rutina_indice', selectorRutinaRapida.value);
        form.append('cliente_nombre', datos.nombre);
        form.append('cliente_telefono', datos.telefono);
        if (pdfMaquinaSinApp && pdfMaquinaSinApp.files && pdfMaquinaSinApp.files.length > 0) {
          form.append('pdf_maquina', pdfMaquinaSinApp.files[0]);
        }
        botonDescargarRutinaPdf.disabled = true;
        botonDescargarRutinaPdf.textContent = 'Generando PDF...';
        mostrarSplash('Generando PDF combinado', 'Estamos creando la rutina de KBeauty y uniéndola con el PDF de la máquina. No cierres esta pantalla.');
        try {
          const res = await fetchSeguro('/kbeauty-data/rutina-sin-app/pdf', { method:'POST', body:form });
          if (!res.ok) throw new Error('No se pudo generar el PDF.');
          const blob = await res.blob();
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          const nombreSeguro = datos.nombre.replace(/[^a-zA-Z0-9_-]+/g, '_').replace(/^_+|_+$/g, '') || 'cliente';
          a.href = url;
          a.download = `rutina_kbeauty_${nombreSeguro}.pdf`;
          document.body.appendChild(a);
          a.click();
          a.remove();
          URL.revokeObjectURL(url);
          pintarRutinaRapida(rutina);
        } catch (err) {
          alert(err.message || 'No se pudo descargar el PDF.');
        } finally {
          ocultarSplash();
          botonDescargarRutinaPdf.textContent = 'Descargar PDF';
          actualizarBotonPdfSinApp();
        }
      });

      function setSubidaActiva(activa) {
        if (activa) {
          mostrarSplash('Subiendo y analizando PDF', 'Estamos guardando el archivo y extrayendo los datos del análisis presencial. No cierres esta pantalla.');
        } else {
          ocultarSplash();
        }
        botonSubirPdf.disabled = activa || !clienteActual;
        archivoPdf.disabled = activa || !clienteActual;
        document.getElementById('notasPdf').disabled = activa || !clienteActual;
        document.getElementById('limpiarSeleccion').disabled = activa;
      }

      function actualizarEstadoUploadPorCliente() {
        const hayCliente = !!clienteActual;
        uploadPanel.classList.toggle('disabled', !hayCliente);
        botonSubirPdf.disabled = !hayCliente;
        archivoPdf.disabled = !hayCliente;
        document.getElementById('notasPdf').disabled = !hayCliente;
        uploadHint.textContent = hayCliente
          ? `PDF para: ${clienteActual.villar_nombre || clienteActual.villar_correo || clienteActual.villar_id}`
          : 'Primero selecciona un cliente para activar la subida.';
      }

      async function fetchSeguro(url, opciones = {}) {
        const res = await fetch(url, opciones);
        if (res.redirected || (res.url && res.url.includes('/kbeauty-data/login'))) {
          window.location.href = res.url || '/kbeauty-data/logout';
          throw new Error('Sesion vencida. Redirigiendo al login...');
        }
        if (res.status === 401) {
          window.location.href = '/kbeauty-data/logout';
          throw new Error('Sesion vencida. Redirigiendo al login...');
        }
        return res;
      }

      input.addEventListener('input', () => {
        const q = input.value.trim();
        clearTimeout(timer);
        if (q.length < 2) { sugerencias.style.display = 'none'; return; }
        timer = setTimeout(() => buscarSugerencias(q), 260);
      });

      async function buscarSugerencias(q) {
        sugerencias.innerHTML = `<div class='suggestion'><div><b>Buscando...</b><div class='s-meta'>Un momento</div></div></div>`;
        sugerencias.style.display = 'block';
        try {
          const res = await fetchSeguro(`/kbeauty-data/clientes/buscar?q=${encodeURIComponent(q)}`);
          const data = await res.json();
          const items = data.datos || [];
          if (!items.length) {
            sugerencias.innerHTML = `<div class='suggestion'><div><b>No hay resultados</b><div class='s-meta'>Prueba con correo, nombre o Villar ID.</div></div></div>`;
            return;
          }
          sugerencias.innerHTML = items.map(c => {
            const nombre = c.villar_nombre || 'Sin nombre';
            const correo = c.villar_correo || 'Correo no disponible';
            const vid = c.villar_id || '';
            return `<div class='suggestion' data-villar='${vid}'>
              <div><div class='s-name'>${nombre}</div><div class='s-meta'>${correo}</div><div class='s-meta'>${vid}</div></div>
              <div class='s-id'>Seleccionar</div>
            </div>`;
          }).join('');
          document.querySelectorAll('.suggestion[data-villar]').forEach(el => {
            el.addEventListener('click', () => seleccionarCliente(el.dataset.villar));
          });
        } catch (e) {
          sugerencias.innerHTML = `<div class='suggestion'><div><b>Error buscando</b><div class='s-meta'>${e}</div></div></div>`;
        }
      }

      async function seleccionarCliente(villarId) {
        sugerencias.style.display = 'none';
        input.value = villarId;
        estadoInicial.classList.add('hidden');
        layout.style.display = 'grid';
        document.getElementById('listaAnalisis').innerHTML = `<div class='analysis-item'>Cargando cliente...</div>`;
        const res = await fetchSeguro(`/kbeauty-data/clientes/${encodeURIComponent(villarId)}/detalle`);
        const data = await res.json();
        if (!data.correcto) { alert(data.mensaje || 'No se pudo cargar'); return; }
        clienteActual = data.datos;
        pintarCliente(clienteActual);
        actualizarEstadoUploadPorCliente();
      }

      function pintarCliente(c) {
        const nombre = c.villar_nombre || 'Sin nombre';
        document.getElementById('clienteAvatar').textContent = iniciales(nombre);
        document.getElementById('clienteNombre').textContent = nombre;
        document.getElementById('clienteCorreo').textContent = c.villar_correo || 'Correo no disponible';
        document.getElementById('clienteVillarId').textContent = texto(c.villar_id);
        document.getElementById('clienteKbeautyId').textContent = texto(c.id);
        const p = c.perfil || {};
        document.getElementById('clienteTipoPiel').textContent = texto(p.tipo_piel);
        document.getElementById('clienteCondicion').textContent = texto(p.condicion_principal);
        document.getElementById('clienteSensibilidad').textContent = texto(p.sensibilidad);
        document.getElementById('villarIdSeleccionado').value = c.villar_id || '';
        document.getElementById('perfilIdSeleccionado').value = p.id || '';
        const analisis = c.analisis || [];
        document.getElementById('contadorAnalisis').textContent = `${analisis.length} análisis`;
        document.getElementById('listaAnalisis').innerHTML = analisis.length ? analisis.map(a => `
          <div class='analysis-item'>
            <div>
              <b>${a.resumen_general || a.archivo_nombre || 'Análisis facial'}</b>
              <div class='small'>${fechaBonita(a.creado_en)}</div>
              <div class='small'>${a.condicion_principal_detectada || a.estado_procesamiento || ''}</div>
            </div>
            <span class='tag ${a.tipo === 'presencial_pdf' ? 'presencial' : ''}'>${a.etiqueta || a.tipo}</span>
          </div>`).join('') : `<div class='analysis-item'><div><b>Sin análisis todavía</b><div class='small'>Cuando subas el PDF aparecerá aquí.</div></div></div>`;
      }

      archivoPdf.addEventListener('change', () => validarArchivo());
      ['dragenter','dragover'].forEach(ev => dropZone.addEventListener(ev, e => { e.preventDefault(); dropZone.classList.add('drag'); }));
      ['dragleave','drop'].forEach(ev => dropZone.addEventListener(ev, e => { e.preventDefault(); dropZone.classList.remove('drag'); }));
      dropZone.addEventListener('drop', e => {
        const file = e.dataTransfer.files[0];
        if (file) { archivoPdf.files = e.dataTransfer.files; validarArchivo(); }
      });

      const dropZoneMaquina = document.getElementById('dropZoneMaquina');
      const nombreArchivoMaquina = document.getElementById('nombreArchivoMaquina');
      if (pdfMaquinaSinApp && dropZoneMaquina) {
        pdfMaquinaSinApp.addEventListener('change', () => validarArchivoMaquina());
        ['dragenter','dragover'].forEach(ev => dropZoneMaquina.addEventListener(ev, e => { e.preventDefault(); dropZoneMaquina.classList.add('drag'); }));
        ['dragleave','drop'].forEach(ev => dropZoneMaquina.addEventListener(ev, e => { e.preventDefault(); dropZoneMaquina.classList.remove('drag'); }));
        dropZoneMaquina.addEventListener('drop', e => {
          const file = e.dataTransfer.files[0];
          if (file) { pdfMaquinaSinApp.files = e.dataTransfer.files; validarArchivoMaquina(); }
        });
      }

      function validarArchivoMaquina() {
        const file = pdfMaquinaSinApp && pdfMaquinaSinApp.files ? pdfMaquinaSinApp.files[0] : null;
        if (!file) {
          if (nombreArchivoMaquina) nombreArchivoMaquina.textContent = '';
          if (dropZoneMaquina) dropZoneMaquina.classList.remove('has-file');
          actualizarBotonPdfSinApp();
          return true;
        }
        if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
          pdfMaquinaSinApp.value = '';
          if (nombreArchivoMaquina) nombreArchivoMaquina.textContent = 'Solo se acepta PDF.';
          if (dropZoneMaquina) dropZoneMaquina.classList.remove('has-file');
          actualizarBotonPdfSinApp();
          return false;
        }
        if (nombreArchivoMaquina) nombreArchivoMaquina.textContent = `Seleccionado: ${file.name}`;
        if (dropZoneMaquina) dropZoneMaquina.classList.add('has-file');
        actualizarBotonPdfSinApp();
        return true;
      }
      function validarArchivo() {
        const file = archivoPdf.files[0];
        if (!file) { nombreArchivo.textContent = ''; dropZone.classList.remove('has-file'); return false; }
        if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
          archivoPdf.value = '';
          nombreArchivo.textContent = 'Solo se acepta PDF.';
          dropZone.classList.remove('has-file');
          return false;
        }
        nombreArchivo.textContent = `Seleccionado: ${file.name}`;
        dropZone.classList.add('has-file');
        return true;
      }

      document.getElementById('limpiarSeleccion').addEventListener('click', () => {
        archivoPdf.value = '';
        document.getElementById('notasPdf').value = '';
        nombreArchivo.textContent = '';
        dropZone.classList.remove('has-file');
        estadoUpload.textContent = '';
      });

      document.getElementById('formPdf').addEventListener('submit', async e => {
        e.preventDefault();
        if (!clienteActual) { alert('Selecciona un cliente primero.'); return; }
        if (!validarArchivo()) return;
        const form = new FormData(e.target);
        estadoUpload.textContent = 'Subiendo y analizando PDF...';
        setSubidaActiva(true);
        try {
          const res = await fetchSeguro('/kbeauty-data/analisis-presencial/subir', { method:'POST', body:form });
          const data = await res.json();
          if (!res.ok || !data.correcto) throw new Error((data.detail && data.detail.mensaje) || data.mensaje || 'Error subiendo PDF');
          estadoUpload.textContent = 'PDF subido correctamente.';
          archivoPdf.value = '';
          nombreArchivo.textContent = '';
          await seleccionarCliente(clienteActual.villar_id);
        } catch (err) {
          estadoUpload.textContent = err.message || 'Error subiendo PDF.';
        } finally {
          setSubidaActiva(false);
        }
      });
    </script>
    """
    contenido = contenido.replace("__RUTINAS_NO_APP_JSON__", rutinas_no_app_json)
    contenido = contenido.replace("__ENLACE_INVITACION_VILLAR__", enlace_invitacion_villar_html)
    return HTMLResponse(_html_base("KBEAUTY-DATA Empleados", contenido, usuario, mostrar_nav=False))


@router.post("/kbeauty-data/rutina-sin-app/pdf")
async def descargar_rutina_sin_app_pdf(
    request: Request,
    rutina_indice: int = Form(...),
    cliente_nombre: str = Form(...),
    cliente_telefono: str = Form(...),
    pdf_maquina: UploadFile = File(None),
):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)

    rutinas = listar_rutinas()
    if rutina_indice < 0 or rutina_indice >= len(rutinas):
        respuesta_error("Rutina no encontrada", 404)

    nombre = (cliente_nombre or "").strip()
    telefono = (cliente_telefono or "").strip()
    if not nombre:
        respuesta_error("El nombre del cliente es obligatorio", 400)
    if not telefono:
        respuesta_error("El numero de telefono del cliente es obligatorio", 400)

    rutina = rutinas[rutina_indice]
    pdf = _crear_pdf_rutina_no_app(nombre, telefono, rutina)
    if pdf_maquina and pdf_maquina.filename:
        nombre_pdf = (pdf_maquina.filename or '').lower()
        if not nombre_pdf.endswith('.pdf'):
            respuesta_error('El archivo de la maquina debe ser PDF', 400)
        contenido_maquina = await pdf_maquina.read()
        if not contenido_maquina.startswith(b'%PDF'):
            respuesta_error('El archivo de la maquina no parece ser un PDF valido', 400)
        pdf = _combinar_pdf_rutina_con_maquina(pdf, contenido_maquina)
    archivo = f"rutina_kbeauty_{_nombre_archivo_seguro(nombre)}.pdf"
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{archivo}"'},
    )


@router.post("/kbeauty-data/analisis-presencial/subir-web")
def subir_pdf_web(request: Request, villar_id: str = Form(...), perfil_id: str = Form(None), notas: str = Form(""), archivo: UploadFile = File(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    guardar_pdf_presencial(villar_id, usuario.get("villar_id"), archivo, perfil_id=perfil_id or None, notas=notas)
    return RedirectResponse("/kbeauty-data/empleados", status_code=303)


@router.get("/kbeauty-data/clientes/{villar_id}/detalle")
def api_detalle_cliente_kdata(request: Request, villar_id: str):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    return respuesta_correcta(
        "Cliente encontrado",
        obtener_cliente_kdata(villar_id, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar")),
    )


@router.get("/kbeauty-data/clientes/buscar")
def api_buscar_clientes(request: Request, q: str = Query(..., min_length=1)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    return respuesta_correcta("Clientes encontrados", buscar_clientes(q, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar")))


@router.post("/kbeauty-data/analisis-presencial/subir")
def api_subir_pdf(request: Request, villar_id: str = Form(...), perfil_id: str = Form(None), notas: str = Form(""), archivo: UploadFile = File(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    registro = guardar_pdf_presencial(villar_id, usuario.get("villar_id"), archivo, perfil_id=perfil_id or None, notas=notas)
    return respuesta_correcta("PDF presencial subido", registro)


@router.get("/analisis-presencial/{analisis_id}")
def api_detalle_presencial(request: Request, analisis_id: str):
    usuario, redireccion = _usuario_web_o_bearer(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    fila = obtener_pdf_presencial(analisis_id, usuario)
    return respuesta_correcta("Analisis presencial", fila)


@router.get("/analisis-presencial/{analisis_id}/pdf")
def api_ver_pdf_presencial(request: Request, analisis_id: str):
    usuario, redireccion = _usuario_web_o_bearer(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    fila = obtener_pdf_presencial(analisis_id, usuario)
    return FileResponse(
        fila["archivo_ruta"],
        media_type="application/pdf",
        filename=fila.get("archivo_nombre") or "analisis.pdf",
    )
