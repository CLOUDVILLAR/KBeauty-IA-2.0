import os
import re
from datetime import date, datetime
from decimal import Decimal
from io import BytesIO
from uuid import UUID, uuid4

from psycopg2.extras import Json
from pypdf import PdfReader

from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from config.configuracion import obtener_configuracion
from servicios.servicio_openai import analizar_pdf_externo_piel
from servicios.servicio_rutinas import obtener_resumen_rutinas
from utilidades.respuestas import respuesta_error


ROLES_KBEAUTY_DATA = {
    "admin",
    "administrador",
    "empleado",
    "staff",
    "kbeauty_data",
    "developer",
}

CARPETA_ANALISIS_PRESENCIALES = os.path.join(
    os.getcwd(),
    "almacenamiento",
    "analisis_presenciales",
)


def _json_seguro(valor):
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    if isinstance(valor, UUID):
        return str(valor)
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, dict):
        return {str(k): _json_seguro(v) for k, v in valor.items()}
    if isinstance(valor, (list, tuple)):
        return [_json_seguro(v) for v in valor]
    return valor


def _nombre_archivo_seguro(nombre):
    nombre = (nombre or "analisis_presencial.pdf").strip()
    nombre = os.path.basename(nombre)
    nombre = re.sub(r"[^A-Za-z0-9._-]+", "_", nombre)
    if not nombre.lower().endswith(".pdf"):
        respuesta_error("Debes subir un archivo PDF", 422)
    return nombre or "analisis_presencial.pdf"


def _asegurar_carpeta():
    os.makedirs(CARPETA_ANALISIS_PRESENCIALES, exist_ok=True)


def validar_permiso_kbeauty_data(usuario):
    roles = usuario.get("roles") or []
    codigos = {str(rol.get("codigo") or "").strip().lower() for rol in roles if isinstance(rol, dict)}
    if codigos.intersection(ROLES_KBEAUTY_DATA):
        return True
    respuesta_error("No tienes permiso para usar KBEAUTY-DATA", 403)


def buscar_clientes_kbeauty(q, limite=20):
    texto = (q or "").strip()
    if len(texto) < 2:
        respuesta_error("Escribe al menos 2 caracteres para buscar", 422)

    patron = f"%{texto}%"
    return consultar_todos(
        """
        SELECT
            u.id,
            u.villar_id,
            u.estado_en_app,
            u.formulario_completado,
            u.ultimo_acceso,
            p.id AS perfil_id,
            p.tipo_piel,
            p.condicion_principal,
            p.rango_edad,
            p.sensibilidad
        FROM usuarios u
        LEFT JOIN perfiles_piel p ON p.villar_id = u.villar_id
        WHERE CAST(u.villar_id AS TEXT) ILIKE %s
           OR CAST(u.id AS TEXT) ILIKE %s
        ORDER BY u.ultimo_acceso DESC NULLS LAST
        LIMIT %s
        """,
        (patron, patron, limite),
    )


def _obtener_cliente(usuario_id=None, villar_id=None):
    if usuario_id:
        cliente = consultar_uno("SELECT * FROM usuarios WHERE id = %s", (usuario_id,))
    elif villar_id:
        cliente = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (villar_id,))
    else:
        respuesta_error("Debes enviar usuario_id o villar_id del cliente", 422)

    if not cliente:
        respuesta_error("Cliente no encontrado en KBeauty", 404)
    return cliente


def _obtener_perfil_cliente(villar_id, perfil_id=None):
    if perfil_id:
        perfil = consultar_uno(
            "SELECT * FROM perfiles_piel WHERE id = %s AND villar_id = %s",
            (perfil_id, villar_id),
        )
        if not perfil:
            respuesta_error("Perfil de piel no encontrado para este cliente", 404)
        return perfil
    return consultar_uno("SELECT * FROM perfiles_piel WHERE villar_id = %s", (villar_id,))


def _extraer_texto_pdf_desde_bytes(bytes_pdf):
    try:
        lector = PdfReader(BytesIO(bytes_pdf))
        textos = []
        for indice, pagina in enumerate(lector.pages):
            if indice >= 15:
                break
            texto = pagina.extract_text() or ""
            if texto.strip():
                textos.append(texto.strip())
    except Exception as exc:
        respuesta_error("No se pudo leer el PDF presencial", 422, {"error": str(exc)[:300]})

    texto_final = "\n\n".join(textos).strip()
    if len(texto_final) < 40:
        respuesta_error(
            "El PDF no tiene texto legible suficiente. Si es un PDF escaneado como imagen, primero exportalo con texto/OCR.",
            422,
        )
    return texto_final[:50000]


def _guardar_archivo_pdf(bytes_pdf, nombre_original):
    _asegurar_carpeta()
    nombre_seguro = _nombre_archivo_seguro(nombre_original)
    nombre_final = f"{uuid4()}_{nombre_seguro}"
    ruta = os.path.join(CARPETA_ANALISIS_PRESENCIALES, nombre_final)
    with open(ruta, "wb") as archivo:
        archivo.write(bytes_pdf)
    return nombre_seguro, ruta


def crear_analisis_presencial_pdf(
    empleado,
    archivo_pdf,
    usuario_id=None,
    villar_id=None,
    perfil_id=None,
    titulo=None,
    notas=None,
):
    validar_permiso_kbeauty_data(empleado)

    nombre_original = _nombre_archivo_seguro(archivo_pdf.filename)
    bytes_pdf = archivo_pdf.file.read()
    if not bytes_pdf:
        respuesta_error("El PDF esta vacio", 422)

    cliente = _obtener_cliente(usuario_id=usuario_id, villar_id=villar_id)
    perfil = _obtener_perfil_cliente(cliente["villar_id"], perfil_id=perfil_id)

    nombre_archivo, ruta_archivo = _guardar_archivo_pdf(bytes_pdf, nombre_original)
    texto_pdf = _extraer_texto_pdf_desde_bytes(bytes_pdf)
    analisis_ia = analizar_pdf_externo_piel(texto_pdf, obtener_resumen_rutinas())

    valores_extraidos = _json_seguro({
        "origen": "presencial_pdf",
        "texto_extraido": texto_pdf[:50000],
        "analisis_ia": analisis_ia,
        "resumen_general": analisis_ia.get("resumen_general"),
        "proveedor_detectado": analisis_ia.get("proveedor_detectado"),
        "tipo_piel_estimado": analisis_ia.get("tipo_piel_estimado"),
        "condicion_principal_detectada": analisis_ia.get("condicion_principal_detectada"),
        "condiciones_detectadas": analisis_ia.get("condiciones_detectadas") or [],
        "metricas_clave": analisis_ia.get("metricas_clave") or [],
        "metricas_no_encontradas": analisis_ia.get("metricas_no_encontradas") or [],
        "puntajes": analisis_ia.get("puntajes") or {},
        "rutina_recomendada_nombre": analisis_ia.get("rutina_recomendada_nombre"),
        "razon_rutina": analisis_ia.get("razon_rutina"),
        "notas": analisis_ia.get("notas") or [],
    })

    registro = ejecutar(
        """
        INSERT INTO analisis_presenciales_pdf (
            usuario_id, perfil_id, empleado_id, titulo, tipo, etiqueta,
            archivo_nombre, archivo_ruta, archivo_url, valores_extraidos,
            estado_procesamiento, notas
        )
        VALUES (%s, %s, %s, %s, 'presencial_pdf', 'Presencial', %s, %s, NULL, %s, 'procesado', %s)
        RETURNING *
        """,
        (
            cliente["id"],
            (perfil or {}).get("id"),
            empleado.get("id"),
            (titulo or "Analisis facial presencial").strip(),
            nombre_archivo,
            ruta_archivo,
            Json(valores_extraidos),
            notas,
        ),
        retornar=True,
    )

    return {
        "analisis_presencial": registro,
        "cliente": {
            "id": cliente.get("id"),
            "villar_id": cliente.get("villar_id"),
        },
        "perfil": perfil,
        "valores_extraidos": valores_extraidos,
    }


def obtener_analisis_presencial(analisis_id, usuario, permitir_empleado=False):
    if permitir_empleado:
        roles = usuario.get("roles") or []
        codigos = {str(rol.get("codigo") or "").strip().lower() for rol in roles if isinstance(rol, dict)}
        if codigos.intersection(ROLES_KBEAUTY_DATA):
            detalle = consultar_uno("SELECT * FROM analisis_presenciales_pdf WHERE id = %s", (analisis_id,))
            if detalle:
                return detalle

    detalle = consultar_uno(
        """
        SELECT ap.*
        FROM analisis_presenciales_pdf ap
        INNER JOIN usuarios u ON u.id = ap.usuario_id
        WHERE ap.id = %s AND u.villar_id = %s
        """,
        (analisis_id, usuario["villar_id"]),
    )
    if not detalle:
        respuesta_error("Analisis presencial no encontrado", 404)
    return detalle


def obtener_ruta_pdf_presencial(analisis_id, usuario):
    detalle = obtener_analisis_presencial(analisis_id, usuario, permitir_empleado=True)
    ruta = detalle.get("archivo_ruta")
    if not ruta or not os.path.isfile(ruta):
        respuesta_error("Archivo PDF no encontrado en el servidor", 404)
    return detalle, ruta
