from fastapi import Header

from config.configuracion import obtener_configuracion
from utilidades.respuestas import respuesta_error


def verificar_clave_promotoras(x_promotoras_key: str = Header(default=None)):
    clave_configurada = obtener_configuracion().get("promotoras_app_key")
    if not clave_configurada:
        respuesta_error("PROMOTORAS_APP_KEY no esta configurada en el servidor", 500)

    if not x_promotoras_key or x_promotoras_key != clave_configurada:
        respuesta_error("Clave de promotoras invalida", 401)

    return True
