import requests
from config.configuracion import obtener_configuracion
from utilidades.respuestas import respuesta_error


def _base_url():
    return obtener_configuracion()["villar_do_api_url"].rstrip("/")


def _timeout():
    return obtener_configuracion()["villar_do_timeout_segundos"]


def _client_id():
    return obtener_configuracion()["villar_do_client_id"]


def _app_key():
    return obtener_configuracion().get("villar_do_app_key") or ""


def llamar_villar_do(metodo, ruta, json=None, token=None):
    url = f"{_base_url()}{ruta}"
    headers = {"Accept": "application/json"}
    app_key = _app_key()
    if app_key:
        # Header nuevo de Villar.do Developer.
        headers["X-Villar-App-Key"] = app_key
        # Compatibilidad con middleware anterior.
        headers["X-Villar-Client-Id"] = _client_id()
        headers["X-Villar-Api-Key"] = app_key
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        respuesta = requests.request(
            metodo,
            url,
            json=json,
            headers=headers,
            timeout=_timeout(),
        )
    except requests.RequestException as error:
        respuesta_error(
            "No se pudo conectar con Villar.do",
            503,
            {"url": url, "error": str(error)},
        )

    try:
        datos = respuesta.json()
    except ValueError:
        respuesta_error(
            "Villar.do respondio con un formato no valido",
            502,
            {"status_code": respuesta.status_code, "texto": respuesta.text[:500]},
        )

    if respuesta.status_code >= 400 or datos.get("ok") is False:
        mensaje = datos.get("error") or datos.get("mensaje") or "Villar.do rechazo la solicitud"
        respuesta_error(mensaje, respuesta.status_code if respuesta.status_code >= 400 else 400, datos)

    return datos


def login_en_villar_do(correo, contrasena):
    return llamar_villar_do(
        "POST",
        "/api/auth/login",
        json={"correo": correo, "contrasena": contrasena, "client_id": _client_id()},
    )


def registrar_en_villar_do(datos):
    cuerpo = dict(datos or {})
    cuerpo["client_id"] = _client_id()
    return llamar_villar_do("POST", "/api/auth/registro", json=cuerpo)


def refrescar_sesion_villar_do(refresh_token):
    return llamar_villar_do("POST", "/api/auth/refresh", json={"refresh_token": refresh_token})


def cerrar_sesion_villar_do(refresh_token):
    return llamar_villar_do("POST", "/api/auth/logout", json={"refresh_token": refresh_token})


def validar_token_villar_do(token):
    return llamar_villar_do("POST", "/api/auth/validar-token", json={"token": token})


def obtener_me_villar_do(token):
    return llamar_villar_do("GET", "/api/auth/me", token=token)
