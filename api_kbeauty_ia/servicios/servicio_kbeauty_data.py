import os
import uuid
from pathlib import Path
from urllib.parse import urlencode

import requests
from fastapi import UploadFile
from psycopg2.extras import Json

from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from config.configuracion import obtener_configuracion
from servicios.servicio_analisis_externo import (
    _json_seguro as _json_seguro_externo,
    _preparar_rutina_desde_ia,
    extraer_texto_pdf,
)
from servicios.servicio_openai import analizar_pdf_externo_piel
from servicios.servicio_rutinas import obtener_resumen_rutinas
from servicios.servicio_usuarios import asegurar_usuario_local, obtener_roles_usuario
from servicios.servicio_villar_do import validar_token_villar_do
from utilidades.respuestas import respuesta_error


ROLES_ADMIN = {"admin_kbeauty", "admin", "administrador", "developer"}
ROLES_EMPLEADO = {"kbeauty_data", "admin_kbeauty", "admin", "administrador", "developer"}


def _cfg():
    return obtener_configuracion()


def _app_url():
    return (_cfg().get("app_url") or "http://localhost:8000").rstrip("/")


def _base_villar():
    return (_cfg().get("villar_do_api_url") or "http://localhost:8100").rstrip("/")


def _app_key():
    return _cfg().get("villar_do_app_key") or ""


def _client_id():
    return _cfg().get("villar_do_client_id") or "kbeauty_ia"


def _timeout():
    return int(_cfg().get("villar_do_timeout_segundos") or 12)


def _cookie_segura():
    return _app_url().startswith("https://")


def _valor_usuario(datos, *claves):
    """Busca un dato aunque Villar.do lo devuelva con otro nombre o anidado."""
    if not isinstance(datos, dict):
        return None

    claves_normalizadas = {str(c).lower() for c in claves}

    def buscar(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if str(k).lower() in claves_normalizadas and v not in (None, ""):
                    return v
            for v in obj.values():
                encontrado = buscar(v)
                if encontrado not in (None, ""):
                    return encontrado
        elif isinstance(obj, list):
            for v in obj:
                encontrado = buscar(v)
                if encontrado not in (None, ""):
                    return encontrado
        return None

    return buscar(datos)


def _normalizar_info_villar(datos):
    if not isinstance(datos, dict):
        return {}
    nombre = _valor_usuario(
        datos,
        "nombre", "name", "nombres", "first_name", "nombre_completo",
        "display_name", "nombre_publico", "full_name"
    )
    apellido = _valor_usuario(datos, "apellido", "apellidos", "last_name")
    if nombre and apellido and str(apellido).lower() not in str(nombre).lower():
        nombre = f"{nombre} {apellido}"
    return {
        "villar_id": _valor_usuario(datos, "villar_id", "id_villar", "id"),
        "nombre": nombre,
        "correo": _valor_usuario(datos, "correo", "email", "correo_electronico", "mail", "username"),
        "telefono": _valor_usuario(datos, "telefono", "phone", "celular", "movil", "telefono_movil"),
    }


def construir_url_login_sso(destino="/kbeauty-data/empleados"):
    redirect_uri = f"{_app_url()}/kbeauty-data/sso/callback"
    parametros = {
        "client_id": _client_id(),
        "redirect_uri": redirect_uri,
        # Villar.do usa "estado" en el SSO web.
        "estado": destino,
    }
    if _app_key():
        parametros["app_key"] = _app_key()
    return f"{_base_villar()}/login?{urlencode(parametros)}"


def extraer_token_callback(query_params):
    for nombre in ("access_token", "token", "t", "jwt"):
        valor = query_params.get(nombre)
        if valor:
            return valor
    return None


def intercambiar_codigo_sso(codigo):
    """Fallback por si Villar.do devuelve code en vez de token directo."""
    if not codigo:
        return None
    headers = {
        "Accept": "application/json",
        "X-Villar-Client-Id": _client_id(),
        "X-Villar-App-Key": _app_key(),
        "X-Villar-Api-Key": _app_key(),
    }
    cuerpo = {
        "code": codigo,
        "client_id": _client_id(),
        "app_key": _app_key(),
        "redirect_uri": f"{_app_url()}/kbeauty-data/sso/callback",
    }
    posibles_rutas = [
        "/api/auth/sso/callback",
        "/api/auth/sso/token",
        "/api/auth/oauth/token",
    ]
    for ruta in posibles_rutas:
        try:
            r = requests.post(f"{_base_villar()}{ruta}", json=cuerpo, headers=headers, timeout=_timeout())
            if r.status_code < 400:
                datos = r.json()
                return datos.get("access_token") or datos.get("token") or datos.get("data", {}).get("access_token")
        except Exception:
            continue
    return None


def usuario_desde_token_web(token):
    if not token:
        return None

    # Si Villar.do responde Token invalido, token vencido o cualquier 401,
    # NO dejamos que FastAPI muestre el JSON crudo al usuario.
    # Devolvemos None para que la vista borre la cookie y mande al login SSO.
    try:
        respuesta_villar = validar_token_villar_do(token)
    except Exception:
        return None

    if not respuesta_villar.get("valido"):
        return None
    usuario_villar = dict(respuesta_villar.get("usuario") or {})
    payload = respuesta_villar.get("payload") or {}
    villar_id = usuario_villar.get("villar_id") or payload.get("villar_id") or respuesta_villar.get("villar_id")
    if villar_id:
        # Algunos endpoints devuelven el villar_id solo en el payload. Lo inyectamos
        # para que la vista pueda empatar sesion local con nombre/correo.
        usuario_villar["villar_id"] = str(villar_id)
    usuario = asegurar_usuario_local(villar_id, usuario_villar)
    usuario["token_villar_do"] = token
    usuario["datos_villar"] = usuario_villar
    usuario["roles"] = obtener_roles_usuario(villar_id)
    return usuario


def codigos_roles(usuario):
    return {rol.get("codigo") for rol in (usuario or {}).get("roles", []) if rol.get("codigo")}


def usuario_tiene_rol(usuario, roles_permitidos):
    return bool(codigos_roles(usuario).intersection(roles_permitidos))


def exigir_admin(usuario):
    if not usuario_tiene_rol(usuario, ROLES_ADMIN):
        respuesta_error("No tienes permiso para KBEAUTY-DATA Admin", 403)
    return True


def exigir_empleado(usuario):
    if not usuario_tiene_rol(usuario, ROLES_EMPLEADO):
        respuesta_error("No tienes permiso para KBEAUTY-DATA Empleados", 403)
    return True


def crear_rol(codigo, nombre, descripcion=""):
    codigo = (codigo or "").strip()
    nombre = (nombre or codigo).strip()
    if not codigo:
        respuesta_error("Codigo de rol requerido", 422)
    existente = consultar_uno("SELECT * FROM roles WHERE codigo = %s", (codigo,))
    if existente:
        return existente
    return ejecutar(
        """
        INSERT INTO roles (codigo, nombre, descripcion)
        VALUES (%s, %s, %s)
        RETURNING *
        """,
        (codigo, nombre, descripcion),
        retornar=True,
    )


def listar_roles():
    return consultar_todos("SELECT * FROM roles ORDER BY codigo")


def asignar_rol_a_villar_id(villar_id, codigo_rol):
    if not villar_id or not codigo_rol:
        respuesta_error("villar_id y rol son requeridos", 422)
    rol = consultar_uno("SELECT * FROM roles WHERE codigo = %s", (codigo_rol,))
    if not rol:
        respuesta_error("Rol no existe", 404)
    existente = consultar_uno(
        "SELECT * FROM usuarios_roles WHERE villar_id = %s AND rol_id = %s",
        (villar_id, rol["id"]),
    )
    if existente:
        return existente
    return ejecutar(
        """
        INSERT INTO usuarios_roles (villar_id, rol_id)
        VALUES (%s, %s)
        RETURNING *
        """,
        (villar_id, rol["id"]),
        retornar=True,
    )


def quitar_rol_a_villar_id(villar_id, codigo_rol):
    if not villar_id or not codigo_rol:
        respuesta_error("villar_id y rol son requeridos", 422)
    rol = consultar_uno("SELECT * FROM roles WHERE codigo = %s", (codigo_rol,))
    if not rol:
        respuesta_error("Rol no existe", 404)
    ejecutar(
        "DELETE FROM usuarios_roles WHERE villar_id = %s AND rol_id = %s RETURNING *",
        (villar_id, rol["id"]),
        retornar=True,
    )
    return True


def eliminar_usuario_kbeauty(villar_id):
    """Elimina un usuario local de KBeauty y sus datos relacionados por villar_id.

    No toca Villar.do. Solo limpia la base local de KBeauty para usuarios viejos,
    pruebas o clientes que ya fueron borrados en identidad central.
    """
    villar_id = str(villar_id or "").strip()
    if not villar_id:
        respuesta_error("villar_id requerido", 422)

    usuario = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (villar_id,))
    if not usuario:
        respuesta_error("Usuario no existe en KBeauty", 404)

    # Borrar hijos antes del usuario para evitar choques con llaves foraneas.
    if _tabla_existe_local("productos_recomendados"):
        ejecutar(
            """
            DELETE FROM productos_recomendados
            WHERE rutina_id IN (
                SELECT id FROM rutinas_recomendadas WHERE villar_id = %s
            )
            RETURNING *
            """,
            (villar_id,),
            retornar=True,
        )

    if _tabla_existe_local("rutinas_recomendadas"):
        ejecutar("DELETE FROM rutinas_recomendadas WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("analisis_zonas"):
        ejecutar(
            """
            DELETE FROM analisis_zonas
            WHERE analisis_id IN (
                SELECT id FROM analisis_piel WHERE villar_id = %s
            )
            RETURNING *
            """,
            (villar_id,),
            retornar=True,
        )

    if _tabla_existe_local("historial_evolucion"):
        ejecutar("DELETE FROM historial_evolucion WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("analisis_piel"):
        ejecutar("DELETE FROM analisis_piel WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("analisis_externos"):
        ejecutar("DELETE FROM analisis_externos WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("analisis_presenciales_pdf"):
        columnas = _columnas_tabla("analisis_presenciales_pdf")
        condiciones = []
        parametros = []
        if "villar_id" in columnas:
            condiciones.append("villar_id = %s")
            parametros.append(villar_id)
        if "empleado_villar_id" in columnas:
            condiciones.append("empleado_villar_id = %s")
            parametros.append(villar_id)
        if "usuario_id" in columnas:
            condiciones.append("usuario_id = %s")
            parametros.append(usuario["id"])
        if "empleado_id" in columnas:
            condiciones.append("empleado_id = %s")
            parametros.append(usuario["id"])
        if condiciones:
            ejecutar(
                f"DELETE FROM analisis_presenciales_pdf WHERE {' OR '.join(condiciones)} RETURNING *",
                tuple(parametros),
                retornar=True,
            )

    if _tabla_existe_local("perfiles_piel"):
        ejecutar("DELETE FROM perfiles_piel WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("chat_ia_mensajes"):
        ejecutar("DELETE FROM chat_ia_mensajes WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("eventos_kbeauty"):
        ejecutar("DELETE FROM eventos_kbeauty WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    if _tabla_existe_local("usuarios_roles"):
        ejecutar("DELETE FROM usuarios_roles WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

    return ejecutar("DELETE FROM usuarios WHERE villar_id = %s RETURNING *", (villar_id,), retornar=True)

def _get_villar(ruta, token=None):
    headers = {
        "Accept": "application/json",
        "X-Villar-Client-Id": _client_id(),
        "X-Villar-App-Key": _app_key(),
        "X-Villar-Api-Key": _app_key(),
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = requests.get(f"{_base_villar()}{ruta}", headers=headers, timeout=_timeout())
    try:
        datos = r.json()
    except Exception:
        datos = {"texto": r.text[:500]}
    return r.status_code, datos


def obtener_info_villar(villar_id, token=None, datos_sesion=None):
    """Trae nombre/correo desde Villar.do.

    1) Si es el usuario logueado, usa la respuesta de validar-token.
    2) Consulta endpoints protegidos de Villar.do.
    3) Devuelve _error si Villar.do no autorizo la lectura, para mostrarlo en debug si hace falta.
    """
    villar_id = str(villar_id or "").strip()
    if not villar_id:
        return {}

    # Si el usuario listado es el mismo de la sesion, no dependemos de /api/usuarios.
    if isinstance(datos_sesion, dict):
        info_sesion = _normalizar_info_villar(datos_sesion)
        sesion_id = str(info_sesion.get("villar_id") or "").strip()
        if sesion_id == villar_id:
            return info_sesion

    errores = []
    rutas = [
        f"/api/usuarios/{villar_id}",
        "/api/auth/me",
        "/api/cuenta",
    ]
    for ruta in rutas:
        try:
            status, datos = _get_villar(ruta, token=token)
            if status >= 400 or (isinstance(datos, dict) and datos.get("ok") is False):
                errores.append(f"{ruta}: {status} {datos.get('error') or datos.get('mensaje') or ''}" if isinstance(datos, dict) else f"{ruta}: {status}")
                continue
            info = _normalizar_info_villar(datos)
            # /api/auth/me y /api/cuenta devuelven el usuario de la sesion. Solo sirven si coincide.
            if ruta in ("/api/auth/me", "/api/cuenta") and str(info.get("villar_id") or "") != villar_id:
                continue
            if info.get("nombre") or info.get("correo") or info.get("telefono"):
                return info
        except Exception as e:
            errores.append(f"{ruta}: {e}")
            continue
    return {"_error": " | ".join(errores[-3:])}


def listar_usuarios_kbeauty(buscar=None, limite=50, token=None, datos_sesion=None):
    buscar = (buscar or "").strip()
    params = []
    where = ""
    # Si el usuario escribe UUID o parte de UUID, filtramos en DB.
    # Si escribe correo/nombre, traemos una muestra y filtramos despues de enriquecer con Villar.do.
    buscar_en_db = bool(buscar and all(ch.lower() in "0123456789abcdef-" for ch in buscar))
    if buscar_en_db:
        where = "WHERE CAST(u.id AS TEXT) ILIKE %s OR CAST(u.villar_id AS TEXT) ILIKE %s"
        params = [f"%{buscar}%", f"%{buscar}%"]
    params.append(max(limite, 80) if buscar and not buscar_en_db else limite)
    usuarios = consultar_todos(
        f"""
        SELECT u.*, p.tipo_piel, p.condicion_principal, p.rango_edad, p.sensibilidad
        FROM usuarios u
        LEFT JOIN LATERAL (
            SELECT * FROM perfiles_piel p2
            WHERE p2.villar_id = u.villar_id
            ORDER BY p2.actualizado_en DESC NULLS LAST, p2.creado_en DESC
            LIMIT 1
        ) p ON true
        {where}
        ORDER BY u.creado_en DESC
        LIMIT %s
        """,
        tuple(params),
    )
    enriquecidos = []
    texto_busqueda = buscar.lower()
    for u in usuarios:
        u["roles"] = obtener_roles_usuario(u["villar_id"])
        info = obtener_info_villar(u["villar_id"], token=token, datos_sesion=datos_sesion)
        u["villar_nombre"] = info.get("nombre")
        u["villar_correo"] = info.get("correo")
        u["villar_telefono"] = info.get("telefono")
        u["villar_error"] = info.get("_error")
        if buscar and not buscar_en_db:
            bolsa = " ".join([
                str(u.get("villar_nombre") or ""),
                str(u.get("villar_correo") or ""),
                str(u.get("villar_telefono") or ""),
                str(u.get("villar_id") or ""),
            ]).lower()
            if texto_busqueda not in bolsa:
                continue
        enriquecidos.append(u)
    return enriquecidos[:limite]


def buscar_clientes(q, token=None, datos_sesion=None):
    return listar_usuarios_kbeauty(q, limite=20, token=token, datos_sesion=datos_sesion)


def _columnas_tabla(nombre_tabla):
    filas = consultar_todos(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (nombre_tabla,),
    )
    return {f["column_name"] for f in filas}


def _directorio_pdfs():
    ruta = Path("almacenamiento") / "analisis_presenciales"
    ruta.mkdir(parents=True, exist_ok=True)
    return ruta


def _actualizar_procesamiento_presencial(analisis_id, estado, valores_extraidos=None, error=None):
    columnas = _columnas_tabla("analisis_presenciales_pdf")
    asignaciones = []
    parametros = []

    if "estado_procesamiento" in columnas:
        asignaciones.append("estado_procesamiento = %s")
        parametros.append(estado)
    if "valores_extraidos" in columnas and valores_extraidos is not None:
        asignaciones.append("valores_extraidos = %s")
        parametros.append(Json(_json_seguro_externo(valores_extraidos)))
    if "error_procesamiento" in columnas:
        asignaciones.append("error_procesamiento = %s")
        parametros.append(error)
    if "actualizado_en" in columnas:
        asignaciones.append("actualizado_en = NOW()")

    if not asignaciones:
        return consultar_uno("SELECT * FROM analisis_presenciales_pdf WHERE id = %s", (analisis_id,))

    parametros.append(analisis_id)
    sql = f"""
        UPDATE analisis_presenciales_pdf
        SET {', '.join(asignaciones)}
        WHERE id = %s
        RETURNING *
    """
    return ejecutar(sql, tuple(parametros), retornar=True)


def _procesar_pdf_presencial(registro_id, archivo: UploadFile):
    """Procesa el PDF presencial reutilizando el analizador de PDF externo.

    No crea registros en analisis_externos. Solo guarda datos internos en
    analisis_presenciales_pdf para que historial/evolucion/chat puedan usarlos.
    """
    try:
        archivo.file.seek(0)
        texto_pdf = extraer_texto_pdf(archivo)
        analisis_ia = analizar_pdf_externo_piel(texto_pdf, obtener_resumen_rutinas())
        rutina_recomendada = _preparar_rutina_desde_ia(analisis_ia)

        valores_extraidos = {
            "origen": "presencial_pdf",
            "texto_extraido": texto_pdf[:50000],
            "analisis_ia": analisis_ia or {},
            "rutina_recomendada": rutina_recomendada or {},
            "resumen_general": (analisis_ia or {}).get("resumen_general"),
            "proveedor_detectado": (analisis_ia or {}).get("proveedor_detectado"),
            "tipo_piel_estimado": (analisis_ia or {}).get("tipo_piel_estimado"),
            "condicion_principal_detectada": (analisis_ia or {}).get("condicion_principal_detectada"),
            "condiciones_detectadas": (analisis_ia or {}).get("condiciones_detectadas") or [],
            "metricas_clave": (analisis_ia or {}).get("metricas_clave") or [],
            "metricas_no_encontradas": (analisis_ia or {}).get("metricas_no_encontradas") or [],
            "puntajes": (analisis_ia or {}).get("puntajes") or {},
            "rutina_recomendada_nombre": (analisis_ia or {}).get("rutina_recomendada_nombre"),
            "razon_rutina": (analisis_ia or {}).get("razon_rutina"),
            "notas": (analisis_ia or {}).get("notas") or [],
        }

        return _actualizar_procesamiento_presencial(
            registro_id,
            "completado",
            valores_extraidos=valores_extraidos,
            error=None,
        )
    except Exception as exc:
        # El PDF queda guardado aunque falle la IA. Asi el empleado/cliente no pierde el archivo.
        return _actualizar_procesamiento_presencial(
            registro_id,
            "error",
            valores_extraidos={},
            error=str(exc)[:1000],
        )


def guardar_pdf_presencial(villar_id, empleado_villar_id, archivo: UploadFile, perfil_id=None, notas=None):
    if not villar_id:
        respuesta_error("villar_id del cliente requerido", 422)
    nombre = archivo.filename or "analisis_presencial.pdf"
    if not nombre.lower().endswith(".pdf"):
        respuesta_error("Solo se permiten archivos PDF", 422)

    usuario = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (villar_id,))
    if not usuario:
        respuesta_error("Cliente no existe en KBeauty", 404)

    empleado = None
    if empleado_villar_id:
        empleado = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (empleado_villar_id,))

    extension = ".pdf"
    nombre_seguro = f"{uuid.uuid4()}{extension}"
    ruta = _directorio_pdfs() / nombre_seguro
    contenido = archivo.file.read()
    ruta.write_bytes(contenido)

    columnas = _columnas_tabla("analisis_presenciales_pdf")
    datos = {
        "archivo_nombre": nombre,
        "archivo_ruta": str(ruta).replace("\\", "/"),
        "archivo_url": None,
        "notas": notas,
        "estado_procesamiento": "pendiente",
        "valores_extraidos": Json({}),
    }
    if "villar_id" in columnas:
        datos["villar_id"] = villar_id
    if "empleado_villar_id" in columnas:
        datos["empleado_villar_id"] = empleado_villar_id
    if "usuario_id" in columnas:
        datos["usuario_id"] = usuario["id"]
    if "empleado_id" in columnas and empleado:
        datos["empleado_id"] = empleado["id"]
    if "perfil_id" in columnas and perfil_id:
        datos["perfil_id"] = perfil_id

    campos = [k for k, v in datos.items() if k in columnas]
    valores = [datos[k] for k in campos]
    placeholders = ", ".join(["%s"] * len(campos))
    sql = f"INSERT INTO analisis_presenciales_pdf ({', '.join(campos)}) VALUES ({placeholders}) RETURNING *"
    registro = ejecutar(sql, tuple(valores), retornar=True)

    # Reutiliza el analizador PDF existente. No crea analisis_externos, solo llena
    # valores_extraidos y cambia estado_procesamiento para el flujo presencial.
    return _procesar_pdf_presencial(registro["id"], archivo) or registro


def obtener_pdf_presencial(analisis_id, usuario_actual):
    columnas = _columnas_tabla("analisis_presenciales_pdf")
    fila = consultar_uno("SELECT * FROM analisis_presenciales_pdf WHERE id = %s", (analisis_id,))
    if not fila:
        respuesta_error("Analisis presencial no encontrado", 404)
    dueño = False
    if "villar_id" in columnas and str(fila.get("villar_id")) == str(usuario_actual.get("villar_id")):
        dueño = True
    if "usuario_id" in columnas:
        usuario = consultar_uno("SELECT * FROM usuarios WHERE id = %s", (fila.get("usuario_id"),))
        if usuario and str(usuario.get("villar_id")) == str(usuario_actual.get("villar_id")):
            dueño = True
    if not dueño and not usuario_tiene_rol(usuario_actual, ROLES_EMPLEADO):
        respuesta_error("No tienes permiso para ver este PDF", 403)
    return fila


def listar_analisis_cliente_kdata(villar_id, limite=30):
    normales = consultar_todos(
        """
        SELECT id, creado_en, resumen_general, condicion_principal_detectada,
               tono_piel, 'app' AS tipo, 'App' AS etiqueta, false AS pdf
        FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (villar_id, limite),
    )

    presenciales = []
    if _tabla_existe_local("analisis_presenciales_pdf"):
        columnas = _columnas_tabla("analisis_presenciales_pdf")
        if "villar_id" in columnas:
            presenciales = consultar_todos(
                """
                SELECT id, creado_en, titulo AS resumen_general, estado_procesamiento,
                       archivo_nombre, 'presencial_pdf' AS tipo, 'Presencial' AS etiqueta, true AS pdf
                FROM analisis_presenciales_pdf
                WHERE villar_id = %s
                ORDER BY creado_en DESC
                LIMIT %s
                """,
                (villar_id, limite),
            )
        elif "usuario_id" in columnas:
            presenciales = consultar_todos(
                """
                SELECT app.id, app.creado_en, app.titulo AS resumen_general, app.estado_procesamiento,
                       app.archivo_nombre, 'presencial_pdf' AS tipo, 'Presencial' AS etiqueta, true AS pdf
                FROM analisis_presenciales_pdf app
                JOIN usuarios u ON u.id = app.usuario_id
                WHERE u.villar_id = %s
                ORDER BY app.creado_en DESC
                LIMIT %s
                """,
                (villar_id, limite),
            )

    historial = list(normales or []) + list(presenciales or [])
    historial.sort(key=lambda x: x.get("creado_en"), reverse=True)
    return historial[:limite]


def _tabla_existe_local(nombre_tabla):
    fila = consultar_uno(
        """
        SELECT 1 AS existe
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (nombre_tabla,),
    )
    return bool(fila)


def obtener_cliente_kdata(villar_id, token=None, datos_sesion=None):
    usuario = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (villar_id,))
    if not usuario:
        respuesta_error("Cliente no existe en KBeauty", 404)
    perfil = consultar_uno(
        """
        SELECT * FROM perfiles_piel
        WHERE villar_id = %s
        ORDER BY actualizado_en DESC NULLS LAST, creado_en DESC
        LIMIT 1
        """,
        (villar_id,),
    )
    info = obtener_info_villar(villar_id, token=token, datos_sesion=datos_sesion)
    return {
        "id": usuario.get("id"),
        "villar_id": usuario.get("villar_id"),
        "estado_en_app": usuario.get("estado_en_app"),
        "formulario_completado": usuario.get("formulario_completado"),
        "creado_en": usuario.get("creado_en"),
        "actualizado_en": usuario.get("actualizado_en"),
        "villar_nombre": info.get("nombre"),
        "villar_correo": info.get("correo"),
        "villar_telefono": info.get("telefono"),
        "villar_error": info.get("_error"),
        "roles": obtener_roles_usuario(villar_id),
        "perfil": perfil or {},
        "analisis": listar_analisis_cliente_kdata(villar_id),
    }
