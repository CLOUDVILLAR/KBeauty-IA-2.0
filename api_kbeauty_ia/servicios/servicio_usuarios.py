from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from utilidades.respuestas import respuesta_error
from servicios.servicio_villar_do import (
    login_en_villar_do,
    registrar_en_villar_do,
    refrescar_sesion_villar_do,
    cerrar_sesion_villar_do,
)


def asegurar_rol_cliente():
    rol = consultar_uno("SELECT * FROM roles WHERE codigo = %s", ("cliente",))
    if rol:
        return rol
    return ejecutar(
        """
        INSERT INTO roles (codigo, nombre, descripcion)
        VALUES (%s, %s, %s)
        RETURNING *
        """,
        ("cliente", "Cliente", "Usuario cliente de KBeauty IA"),
        retornar=True,
    )


def obtener_usuario_por_villar_id(villar_id):
    usuario = consultar_uno("SELECT * FROM usuarios WHERE villar_id = %s", (villar_id,))
    if not usuario:
        return None
    usuario["roles"] = obtener_roles_usuario(villar_id)
    return usuario


def obtener_usuario_por_id(usuario_id):
    usuario = consultar_uno("SELECT * FROM usuarios WHERE id = %s", (usuario_id,))
    if not usuario:
        return None
    usuario["roles"] = obtener_roles_usuario(usuario["villar_id"])
    return usuario


def obtener_roles_usuario(villar_id):
    filas = consultar_todos(
        """
        SELECT r.codigo, r.nombre
        FROM roles r
        INNER JOIN usuarios_roles ur ON ur.rol_id = r.id
        WHERE ur.villar_id = %s
        ORDER BY r.codigo
        """,
        (villar_id,),
    )
    return filas


def asignar_rol(villar_id, codigo_rol):
    asegurar_rol_cliente()
    rol = consultar_uno("SELECT * FROM roles WHERE codigo = %s", (codigo_rol,))
    if not rol:
        respuesta_error("Rol no encontrado", 404)
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


def asegurar_usuario_local(villar_id, datos_villar=None):
    if not villar_id:
        respuesta_error("Villar.do no devolvio villar_id", 502)

    usuario = obtener_usuario_por_villar_id(villar_id)
    if usuario:
        ejecutar("UPDATE usuarios SET ultimo_acceso = NOW() WHERE villar_id = %s", (villar_id,))
        usuario = obtener_usuario_por_villar_id(villar_id)
        usuario["datos_villar"] = datos_villar or {}
        return usuario

    asegurar_rol_cliente()
    usuario = ejecutar(
        """
        INSERT INTO usuarios (villar_id, estado_en_app, formulario_completado, ultimo_acceso)
        VALUES (%s, 'activo', false, NOW())
        RETURNING *
        """,
        (villar_id,),
        retornar=True,
    )
    asignar_rol(villar_id, "cliente")
    usuario = obtener_usuario_por_villar_id(villar_id)
    usuario["datos_villar"] = datos_villar or {}
    return usuario


def construir_respuesta_autenticacion(respuesta_villar):
    usuario_villar = respuesta_villar.get("usuario") or {}
    villar_id = respuesta_villar.get("villar_id") or usuario_villar.get("villar_id")
    usuario_local = asegurar_usuario_local(villar_id, usuario_villar)
    access_token = respuesta_villar.get("access_token") or respuesta_villar.get("token")
    return {
        "usuario": usuario_local,
        "usuario_villar": usuario_villar,
        "villar_id": str(villar_id),
        "token": access_token,
        "access_token": access_token,
        "refresh_token": respuesta_villar.get("refresh_token"),
        "token_type": respuesta_villar.get("token_type", "Bearer"),
        "origen_identidad": "villar.do",
    }


def crear_usuario(datos):
    respuesta_villar = registrar_en_villar_do(datos)
    return construir_respuesta_autenticacion(respuesta_villar)


def iniciar_sesion(datos):
    correo = (datos or {}).get("correo")
    contrasena = (datos or {}).get("contrasena") or (datos or {}).get("password")
    if not correo or not contrasena:
        respuesta_error("Correo y contrasena son obligatorios", 422)
    respuesta_villar = login_en_villar_do(correo, contrasena)
    return construir_respuesta_autenticacion(respuesta_villar)


def refrescar_sesion(datos):
    refresh_token = (datos or {}).get("refresh_token")
    if not refresh_token:
        respuesta_error("refresh_token requerido", 422)
    respuesta_villar = refrescar_sesion_villar_do(refresh_token)
    return construir_respuesta_autenticacion(respuesta_villar)


def cerrar_sesion(datos):
    refresh_token = (datos or {}).get("refresh_token")
    if not refresh_token:
        return {"mensaje": "Sesion local cerrada"}
    return cerrar_sesion_villar_do(refresh_token)


def listar_roles():
    return consultar_todos("SELECT * FROM roles ORDER BY codigo")
