from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from utilidades.respuestas import respuesta_error
from servicios.servicio_villar_do import validar_token_villar_do
from servicios.servicio_usuarios import asegurar_usuario_local

seguridad_http = HTTPBearer(auto_error=False)


def obtener_usuario_actual(credenciales: HTTPAuthorizationCredentials = Depends(seguridad_http)):
    if credenciales is None:
        respuesta_error("Token requerido", 401)

    token = credenciales.credentials
    respuesta_villar = validar_token_villar_do(token)

    if not respuesta_villar.get("valido"):
        respuesta_error("Token invalido", 401, respuesta_villar)

    usuario_villar = respuesta_villar.get("usuario") or {}
    payload = respuesta_villar.get("payload") or {}
    villar_id = usuario_villar.get("villar_id") or payload.get("villar_id")

    usuario = asegurar_usuario_local(villar_id, usuario_villar)
    if usuario.get("estado_en_app") != "activo":
        respuesta_error("Usuario no activo en KBeauty", 403)

    usuario["token_villar_do"] = token
    usuario["payload_villar_do"] = payload
    usuario["datos_villar"] = usuario_villar
    return usuario
