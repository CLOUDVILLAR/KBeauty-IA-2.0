import os
from dotenv import load_dotenv

load_dotenv()


def obtener_variable(nombre, valor_defecto=None):
    valor = os.getenv(nombre)
    if valor is None or valor == "":
        return valor_defecto
    return valor


def obtener_booleano(nombre, valor_defecto=False):
    valor = obtener_variable(nombre)
    if valor is None:
        return valor_defecto
    return str(valor).strip().lower() in ["1", "true", "si", "sí", "yes", "on"]


def obtener_entero(nombre, valor_defecto=0):
    valor = obtener_variable(nombre)
    if valor is None:
        return valor_defecto
    valor = str(valor).split("#")[0].strip()
    try:
        return int(valor)
    except (TypeError, ValueError):
        return valor_defecto


def obtener_lista(nombre, valor_defecto=None):
    valor = obtener_variable(nombre)
    if not valor:
        return valor_defecto or []
    if valor.strip() == "*":
        return ["*"]
    return [item.strip() for item in valor.split(",") if item.strip()]


APP_NOMBRE = obtener_variable("APP_NOMBRE", "KBeauty IA API")
APP_DEBUG = obtener_booleano("APP_DEBUG", True)
APP_HOST = obtener_variable("APP_HOST", "0.0.0.0")
APP_PORT = obtener_entero("APP_PORT", 8000)
APP_URL = obtener_variable("APP_URL", "http://localhost:8000")

DATABASE_URL = obtener_variable(
    "DATABASE_URL",
    "postgresql://kbeauty_user:kbeauty123@localhost:5432/kbeauty_ia_v2",
)

# KBeauty ya no firma tokens propios para login. Valida tokens emitidos por Villar.do.
VILLAR_DO_API_URL = obtener_variable("VILLAR_DO_API_URL", "http://localhost:8100")
VILLAR_DO_CLIENT_ID = obtener_variable("VILLAR_DO_CLIENT_ID", "kbeauty_ia")
VILLAR_DO_APP_KEY = obtener_variable("VILLAR_DO_APP_KEY", "")
VILLAR_DO_TIMEOUT_SEGUNDOS = obtener_entero("VILLAR_DO_TIMEOUT_SEGUNDOS", 12)
# Opcional: token Bearer de Villar.do para enriquecer vistas internas con nombre/correo.
# Si no se configura, KBEAUTY-DATA funciona igual, pero solo muestra id/villar_id locales.
VILLAR_DO_ADMIN_TOKEN = obtener_variable("VILLAR_DO_ADMIN_TOKEN", "")

OPENAI_API_KEY = obtener_variable("OPENAI_API_KEY", "")
OPENAI_MODELO = obtener_variable("OPENAI_MODELO", "gpt-4.1-mini")
OPENAI_MODO_DEMO = obtener_booleano("OPENAI_MODO_DEMO", False)

ODOO_URL = obtener_variable("ODOO_URL", "")
ODOO_DB = obtener_variable("ODOO_DB", "")
ODOO_USER = obtener_variable("ODOO_USER", "")
ODOO_PASSWORD = obtener_variable("ODOO_PASSWORD", "")
ODOO_ACTIVO = obtener_booleano("ODOO_ACTIVO", False)

RUTA_RUTINAS = obtener_variable("RUTA_RUTINAS", "datos/Completa_rutinas.json")
RUTA_IMAGENES = obtener_variable("RUTA_IMAGENES", "")
CORS_ORIGENES = obtener_lista("CORS_ORIGENES", ["*"])


def obtener_configuracion():
    return {
        "app_nombre": APP_NOMBRE,
        "app_debug": APP_DEBUG,
        "app_host": APP_HOST,
        "app_port": APP_PORT,
        "app_url": APP_URL,
        "app_version": "2.0.0-villar-do",
        "app_descripcion": "API KBeauty conectada a Villar.do para identidad centralizada.",
        "cors_origenes": CORS_ORIGENES,
        "database_url": DATABASE_URL,
        "villar_do_api_url": VILLAR_DO_API_URL,
        "villar_do_client_id": VILLAR_DO_CLIENT_ID,
        "villar_do_app_key": VILLAR_DO_APP_KEY,
        "villar_do_timeout_segundos": VILLAR_DO_TIMEOUT_SEGUNDOS,
        "villar_do_admin_token": VILLAR_DO_ADMIN_TOKEN,
        "openai_api_key": OPENAI_API_KEY,
        "openai_modelo": OPENAI_MODELO,
        "openai_modo_demo": OPENAI_MODO_DEMO,
        "odoo_url": ODOO_URL,
        "odoo_db": ODOO_DB,
        "odoo_user": ODOO_USER,
        "odoo_password": ODOO_PASSWORD,
        "odoo_activo": ODOO_ACTIVO,
        "ruta_rutinas": RUTA_RUTINAS,
        "ruta_imagenes": RUTA_IMAGENES,
    }
