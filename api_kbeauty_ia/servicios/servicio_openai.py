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



def generar_respuesta_chat_kbeauty(mensaje_usuario, contexto, mensajes_previos=None):
    configuracion = obtener_configuracion()
    api_key = configuracion.get("openai_api_key")
    if not api_key or api_key == "pon_tu_openai_api_key_aqui":
        respuesta_error("OPENAI_API_KEY no esta configurada para el chat IA", 500)

    instrucciones = """
Eres el chat unico de KBeauty IA. Responde en espanol, con tono claro, cercano y practico.
Tu objetivo es orientar sobre skincare de forma cosmetica, no diagnosticar enfermedades.
Usa el contexto clinico-cosmetico disponible: perfil de piel, rutina recomendada, primer analisis y dos ultimos analisis.
Reglas:
- No inventes resultados de analisis que no esten en el contexto.
- Si falta informacion, dilo y pide una accion simple.
- Da pasos concretos y seguros.
- Evita indicar medicamentos, tratamientos medicos o diagnosticos. Recomienda dermatologo ante lesiones, dolor, irritacion fuerte, sangrado, alergias o cambios rapidos.
- Si el usuario pregunta por productos, conecta la respuesta con su rutina guardada cuando exista.
""".strip()

    historial = []
    for item in (mensajes_previos or [])[-12:]:
        rol = item.get("rol")
        contenido = item.get("contenido")
        if rol in ("user", "assistant") and contenido:
            historial.append({"role": rol, "content": str(contenido)[:2500]})

    cliente = OpenAI(api_key=api_key)
    try:
        respuesta = cliente.responses.create(
            model=configuracion["openai_modelo"],
            input=[
                {"role": "system", "content": instrucciones},
                {"role": "system", "content": "Contexto disponible de KBeauty IA:\n" + json.dumps(contexto, ensure_ascii=False, default=str)[:14000]},
                *historial,
                {"role": "user", "content": mensaje_usuario},
            ],
        )
    except Exception as exc:
        logger.exception("[OPENAI] Error al generar respuesta de chat")
        respuesta_error("No se pudo generar la respuesta del chat IA", 502, {"error": str(exc)[:500]})

    texto = getattr(respuesta, "output_text", None)
    if not texto:
        respuesta_error("OpenAI no devolvio respuesta para el chat", 502)
    return texto.strip()


def crear_prompt_analisis_externo_pdf(texto_pdf, rutinas_resumen):
    return f"""
Actua como cosmetologa profesional para KBeauty IA. Vas a interpretar un PDF externo de una maquina facial.
El PDF puede traer metricas con nombres variables, porcentajes, puntajes o textos tecnicos. Tu trabajo es convertirlo a un analisis claro para el usuario y elegir UNA rutina existente.

Reglas importantes:
- No diagnostiques enfermedades.
- No inventes productos fuera de las rutinas disponibles.
- No uses ni asumas perfil del usuario, tipo de piel guardado, rutina actual, historial ni evolucion.
- Basa TODO el analisis y la rutina recomendada exclusivamente en el texto extraido del PDF.
- Elige la rutina por el nombre exacto de la lista de rutinas disponibles.
- Si el PDF no permite concluir algo, coloca null en el campo correspondiente y agrega una nota clara. No inventes datos faltantes.
- Devuelve solo JSON valido, sin markdown.
- Los puntajes van de 0 a 100, donde 0 significa sin problema visible o reportado y 100 significa problema muy marcado. Si una metrica no aparece en el PDF, usa null.
- Para metricas_clave, incluye solo datos que aparezcan o se puedan inferir claramente del PDF. Si falta una metrica importante, ponla en metricas_no_encontradas.

Rutinas disponibles, usa exactamente uno de estos nombres:
{json.dumps(rutinas_resumen or [], ensure_ascii=False, default=str)}

Texto extraido del PDF externo:
{(texto_pdf or '')[:18000]}

Formato exacto:
{{
  "resumen_general": "texto breve y claro o null",
  "proveedor_detectado": "nombre de maquina/proveedor si aparece o null",
  "tipo_piel_estimado": "seca|grasa|mixta|normal|sensible|null",
  "condicion_principal_detectada": "none|melasma|manchas|acne|arrugas|opaca|anti-age|null",
  "condiciones_detectadas": ["string"],
  "metricas_clave": [
    {{"nombre": "hidratacion", "valor": 0, "unidad": "%", "interpretacion": "texto"}}
  ],
  "metricas_no_encontradas": ["string"],
  "puntajes": {{
    "poros": null,
    "manchas_uv_estimadas": null,
    "manchas_generales": null,
    "arrugas": null,
    "elasticidad": null,
    "textura": null,
    "rojeces": null,
    "acne": null,
    "ojeras": null,
    "resequedad": null,
    "grasa": null,
    "uniformidad_tono": null
  }},
  "rutina_recomendada_nombre": "nombre exacto de una rutina disponible",
  "razon_rutina": "por que esa rutina encaja con los datos encontrados en el PDF",
  "recomendaciones_generales": ["string"],
  "notas": ["string"]
}}
""".strip()

def analizar_pdf_externo_piel(texto_pdf, rutinas_resumen):
    configuracion = obtener_configuracion()
    api_key = configuracion.get("openai_api_key")
    if not api_key or api_key == "pon_tu_openai_api_key_aqui":
        respuesta_error("OPENAI_API_KEY no esta configurada. Se requiere OpenAI para interpretar el PDF externo.", 500)

    if not texto_pdf or len(texto_pdf.strip()) < 40:
        respuesta_error("No se pudo extraer texto suficiente del PDF externo", 422)

    modelo = configuracion["openai_modelo"]
    logger.info("[OPENAI] Enviando analisis externo PDF con modelo %s", modelo)
    cliente = OpenAI(api_key=api_key)

    try:
        respuesta = cliente.responses.create(
            model=modelo,
            input=[
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": crear_prompt_analisis_externo_pdf(texto_pdf, rutinas_resumen)},
                    ],
                }
            ],
        )
    except Exception as exc:
        logger.exception("[OPENAI] Error al analizar PDF externo")
        respuesta_error("No se pudo analizar el PDF externo con OpenAI", 502, {"error": str(exc)[:500]})

    resultado = extraer_json_desde_texto(getattr(respuesta, "output_text", None))
    resultado["generado_con_ia"] = True
    resultado["proveedor_ia"] = "openai"
    resultado["modelo_ia"] = modelo
    resultado["fuente"] = "pdf_externo"
    return resultado
