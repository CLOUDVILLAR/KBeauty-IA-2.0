import re
from utilidades.respuestas import respuesta_error


def validar_campos(datos, campos):
    faltantes = [campo for campo in campos if datos.get(campo) in [None, ""]]
    if faltantes:
        respuesta_error("Faltan campos requeridos", 422, {"campos": faltantes})


def validar_correo(correo):
    patron = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"
    if not re.match(patron, correo or ""):
        respuesta_error("Correo electronico invalido", 422)


def validar_contrasena(contrasena):
    if not contrasena or len(contrasena) < 6:
        respuesta_error("La contrasena debe tener al menos 6 caracteres", 422)


def limpiar_texto(valor):
    if valor is None:
        return ""
    return str(valor).strip()


def limpiar_correo(correo):
    return limpiar_texto(correo).lower()
