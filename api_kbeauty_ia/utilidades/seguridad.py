# KBeauty no maneja contrasenas ni tokens propios desde la integracion con Villar.do.
# Este archivo queda solo por compatibilidad con imports antiguos.

def usuario_tiene_rol(usuario, codigo_rol):
    roles = usuario.get("roles") or []
    codigos = []
    for rol in roles:
        if isinstance(rol, dict):
            codigos.append(rol.get("codigo"))
        else:
            codigos.append(str(rol))
    return codigo_rol in codigos


def exigir_rol(usuario, codigo_rol):
    from utilidades.respuestas import respuesta_error
    if not usuario_tiene_rol(usuario, codigo_rol):
        respuesta_error("No tienes permiso para realizar esta accion", 403)
