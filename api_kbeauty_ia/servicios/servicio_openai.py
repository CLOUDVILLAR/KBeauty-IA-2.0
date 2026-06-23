import json
import logging

from openai import OpenAI

from config.configuracion import obtener_configuracion
from utilidades.imagenes import crear_data_url_imagen
from utilidades.respuestas import respuesta_error

logger = logging.getLogger("kbeauty.openai")


def crear_prompt_analisis():
    return """
Actua como asistente cosmetico para una app de skincare. Analiza tres fotos del rostro de forma orientativa, sin diagnosticar enfermedades.
Las fotos llegan en este orden: 1) frente, 2) lado izquierdo, 3) lado derecho.
Devuelve solo JSON valido, sin markdown, sin texto extra.

Reglas:
- Los puntajes van de 0 a 100, donde 0 significa sin problema visible y 100 significa problema muy marcado.
- Si no puedes evaluar una metrica, usa un valor estimado prudente y agrega una nota.
- Las manchas UV desde fotos normales deben tratarse como estimacion visual, no medicion real UV.
- Usa las tres fotos para comparar zonas y mejorar la precision.
- Divide el rostro por zonas: frente, centro, mejilla_izquierda, mejilla_derecha, menton.
- Indica recomendaciones generales breves y accionables.
- Agrega notas si la luz, enfoque, maquillaje o angulo afectan la precision.

Formato exacto:
{
  "resumen_general": "texto breve",
  "tono_piel": "texto breve",
  "condicion_principal_detectada": "none|melasma|manchas|acne|arrugas|opaca|anti-age",
  "condiciones_detectadas": ["string"],
  "puntajes": {
    "poros": 0,
    "manchas_uv_estimadas": 0,
    "manchas_generales": 0,
    "arrugas": 0,
    "elasticidad": 0,
    "textura": 0,
    "rojeces": 0,
    "acne": 0,
    "ojeras": 0,
    "resequedad": 0,
    "grasa": 0,
    "uniformidad_tono": 0
  },
  "zonas": {
    "frente": {"resumen": "", "poros": 0, "manchas": 0, "arrugas": 0, "rojeces": 0, "acne": 0},
    "centro": {"resumen": "", "poros": 0, "manchas": 0, "arrugas": 0, "rojeces": 0, "acne": 0},
    "mejilla_izquierda": {"resumen": "", "poros": 0, "manchas": 0, "arrugas": 0, "rojeces": 0, "acne": 0},
    "mejilla_derecha": {"resumen": "", "poros": 0, "manchas": 0, "arrugas": 0, "rojeces": 0, "acne": 0},
    "menton": {"resumen": "", "poros": 0, "manchas": 0, "arrugas": 0, "rojeces": 0, "acne": 0}
  },
  "recomendaciones_generales": ["string"],
  "notas": ["string"]
}
""".strip()


def extraer_json_desde_texto(texto):
    if not texto:
        respuesta_error("OpenAI no devolvio contenido", 502)

    texto = texto.strip()
    if texto.startswith("```"):
        texto = texto.replace("```json", "").replace("```", "").strip()

    inicio = texto.find("{")
    fin = texto.rfind("}")
    if inicio >= 0 and fin >= 0:
        texto = texto[inicio:fin + 1]

    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        respuesta_error("No se pudo interpretar el JSON devuelto por OpenAI", 502, {"respuesta": texto[:500]})


def validar_respuesta_ia(resultado):
    claves = ["resumen_general", "puntajes", "zonas"]
    faltantes = [clave for clave in claves if clave not in resultado]
    if faltantes:
        respuesta_error("La respuesta de OpenAI esta incompleta", 502, {"faltantes": faltantes})
    return resultado


def crear_bloques_imagenes(imagenes):
    bloques = []
    nombres = ["Foto frontal", "Foto lado izquierdo", "Foto lado derecho"]

    for indice, imagen in enumerate(imagenes):
        bloques.append({"type": "input_text", "text": nombres[indice]})
        bloques.append({
            "type": "input_image",
            "image_url": crear_data_url_imagen(
                imagen["bytes"],
                imagen.get("content_type") or "image/jpeg",
            ),
        })

    return bloques


def analizar_imagenes_piel(imagenes):
    configuracion = obtener_configuracion()

    # Modo demo eliminado: desde este parche todo analisis real exige OpenAI.
    api_key = configuracion.get("openai_api_key")
    if not api_key or api_key == "pon_tu_openai_api_key_aqui":
        respuesta_error("OPENAI_API_KEY no esta configurada. KBeauty IA ahora requiere OpenAI para generar analisis reales.", 500)

    if not imagenes or len(imagenes) != 3:
        respuesta_error("Debes enviar tres imagenes: frente, lado izquierdo y lado derecho", 422)

    modelo = configuracion["openai_modelo"]
    logger.info("[OPENAI] Enviando analisis de piel con modelo %s", modelo)

    cliente = OpenAI(api_key=api_key)
    contenido = [{"type": "input_text", "text": crear_prompt_analisis()}]
    contenido.extend(crear_bloques_imagenes(imagenes))

    try:
        respuesta = cliente.responses.create(
            model=modelo,
            input=[
                {
                    "role": "user",
                    "content": contenido,
                }
            ],
        )
    except Exception as exc:
        logger.exception("[OPENAI] Error al generar analisis")
        respuesta_error("No se pudo generar el analisis con OpenAI", 502, {"error": str(exc)[:500]})

    texto = getattr(respuesta, "output_text", None)
    resultado = validar_respuesta_ia(extraer_json_desde_texto(texto))
    resultado["generado_con_ia"] = True
    resultado["proveedor_ia"] = "openai"
    resultado["modelo_ia"] = modelo
    resultado["modo_demo"] = False
    logger.info("[OPENAI] Analisis recibido correctamente")
    return resultado


def analizar_imagen_piel(bytes_imagen, content_type):
    # Compatibilidad con llamadas antiguas de una sola imagen.
    # Tambien usa OpenAI: duplica la imagen solo para no romper endpoints antiguos.
    return analizar_imagenes_piel([
        {"nombre": "frente", "bytes": bytes_imagen, "content_type": content_type},
        {"nombre": "lado_izquierdo", "bytes": bytes_imagen, "content_type": content_type},
        {"nombre": "lado_derecho", "bytes": bytes_imagen, "content_type": content_type},
    ])
