from base_datos.conexion import consultar_todos, consultar_uno, ejecutar
from psycopg2.extras import Json
from utilidades.normalizacion import convertir_a_numero
from utilidades.respuestas import respuesta_error

# En el analisis de OpenAI los puntajes van de 0 a 100:
# 0 = sin problema visible, 100 = problema muy marcado.
# Por eso, para casi todas las metricas, bajar es mejorar.
METRICAS = [
    "poros",
    "manchas_uv_estimadas",
    "manchas_generales",
    "arrugas",
    "elasticidad",
    "textura",
    "rojeces",
    "acne",
    "ojeras",
    "resequedad",
    "grasa",
    "uniformidad_tono",
]

NOMBRES_METRICAS = {
    "poros": "Poros",
    "manchas_uv_estimadas": "Manchas UV estimadas",
    "manchas_generales": "Manchas generales",
    "arrugas": "Arrugas",
    "elasticidad": "Elasticidad",
    "textura": "Textura",
    "rojeces": "Rojeces",
    "acne": "Acne",
    "ojeras": "Ojeras",
    "resequedad": "Resequedad",
    "grasa": "Grasa",
    "uniformidad_tono": "Uniformidad del tono",
}


def obtener_analisis_usuario(villar_id, analisis_id):
    analisis = consultar_uno(
        "SELECT * FROM analisis_piel WHERE id = %s AND villar_id = %s",
        (analisis_id, villar_id),
    )
    if not analisis:
        respuesta_error("Analisis no encontrado", 404)
    return analisis


def _calcular_porcentaje_mejora(valor_antes, valor_actual):
    # Como menor puntaje = mejor, la mejora es cuanto bajo el problema.
    diferencia_mejora = valor_antes - valor_actual
    if valor_antes > 0:
        porcentaje = (diferencia_mejora / valor_antes) * 100
    elif valor_actual == 0:
        porcentaje = 0
    else:
        # Antes no habia problema y ahora aparecio uno.
        porcentaje = -100
    return diferencia_mejora, porcentaje


def _estado_desde_diferencia(diferencia_mejora):
    if diferencia_mejora > 0:
        return "mejoro"
    if diferencia_mejora < 0:
        return "empeoro"
    return "igual"


def _mensaje_metrica(nombre, antes, actual, diferencia_mejora, porcentaje):
    etiqueta = NOMBRES_METRICAS.get(nombre, nombre.replace("_", " ").title())
    if diferencia_mejora > 0:
        return f"{etiqueta} bajo de {antes:.1f} a {actual:.1f}. Mejora estimada: {porcentaje:.1f}%."
    if diferencia_mejora < 0:
        return f"{etiqueta} subio de {antes:.1f} a {actual:.1f}. Requiere seguimiento."
    return f"{etiqueta} se mantiene igual en {actual:.1f}."


def calcular_cambio_metricas(anterior, actual):
    puntajes_antes = anterior.get("puntajes") or {}
    puntajes_actuales = actual.get("puntajes") or {}
    cambios = {}
    metricas_lista = []
    porcentajes = []

    for metrica in METRICAS:
        valor_antes = convertir_a_numero(puntajes_antes.get(metrica))
        valor_actual = convertir_a_numero(puntajes_actuales.get(metrica))
        diferencia_mejora, porcentaje = _calcular_porcentaje_mejora(valor_antes, valor_actual)
        estado = _estado_desde_diferencia(diferencia_mejora)
        cambio_bruto = valor_actual - valor_antes
        item = {
            "clave": metrica,
            "nombre": NOMBRES_METRICAS.get(metrica, metrica.replace("_", " ").title()),
            "antes": round(valor_antes, 2),
            "actual": round(valor_actual, 2),
            "cambio_bruto": round(cambio_bruto, 2),
            "diferencia_mejora": round(diferencia_mejora, 2),
            "porcentaje_mejora": round(porcentaje, 2),
            "estado": estado,
            "interpretacion": _mensaje_metrica(metrica, valor_antes, valor_actual, diferencia_mejora, porcentaje),
        }
        cambios[metrica] = item
        metricas_lista.append(item)
        porcentajes.append(porcentaje)

    promedio = sum(porcentajes) / len(porcentajes) if porcentajes else 0
    mejoras = [m for m in metricas_lista if m["estado"] == "mejoro"]
    alertas = [m for m in metricas_lista if m["estado"] == "empeoro"]
    estables = [m for m in metricas_lista if m["estado"] == "igual"]

    mejoras_destacadas = sorted(mejoras, key=lambda m: m["porcentaje_mejora"], reverse=True)[:3]
    alertas_destacadas = sorted(alertas, key=lambda m: m["porcentaje_mejora"])[:3]

    return {
        "metricas": cambios,
        "metricas_lista": metricas_lista,
        "porcentaje_general": round(promedio, 2),
        "total_metricas": len(metricas_lista),
        "metricas_mejoraron": len(mejoras),
        "metricas_empeoraron": len(alertas),
        "metricas_estables": len(estables),
        "mejoras_destacadas": mejoras_destacadas,
        "alertas_destacadas": alertas_destacadas,
        "nota_calculo": "Los puntajes de KBeauty IA van de 0 a 100. En general, bajar el puntaje significa menos problema visible y por tanto mejora.",
    }


def generar_resumen_evolucion(cambio):
    porcentaje = cambio.get("porcentaje_general", 0)
    mejoraron = cambio.get("metricas_mejoraron", 0)
    empeoraron = cambio.get("metricas_empeoraron", 0)
    total = cambio.get("total_metricas", 0)

    if porcentaje > 5:
        return f"Tu piel muestra una mejora general aproximada de {porcentaje}%: {mejoraron} de {total} metricas mejoraron."
    if porcentaje < -5:
        return f"Algunas metricas necesitan seguimiento. Cambio general aproximado: {porcentaje}%. Mejoraron {mejoraron} y empeoraron {empeoraron}."
    return f"La piel se mantiene estable. Mejoraron {mejoraron} metricas, empeoraron {empeoraron} y el cambio general fue {porcentaje}%."


def construir_comparacion(anterior, actual):
    cambio = calcular_cambio_metricas(anterior, actual)
    resumen = generar_resumen_evolucion(cambio)
    return {
        "resumen": resumen,
        "cambio": cambio,
        # Compatibilidad con versiones viejas del Flutter.
        "cambios": cambio.get("metricas"),
        "metricas": cambio.get("metricas"),
        "metricas_lista": cambio.get("metricas_lista"),
        "porcentaje_general": cambio.get("porcentaje_general", 0),
        "mejoras_destacadas": cambio.get("mejoras_destacadas", []),
        "alertas_destacadas": cambio.get("alertas_destacadas", []),
        "resumen_numerico": {
            "total_metricas": cambio.get("total_metricas", 0),
            "mejoraron": cambio.get("metricas_mejoraron", 0),
            "empeoraron": cambio.get("metricas_empeoraron", 0),
            "estables": cambio.get("metricas_estables", 0),
        },
    }


def guardar_comparacion(villar_id, analisis_anterior_id, analisis_actual_id, comparacion):
    cambio = comparacion.get("cambio") or {}
    return ejecutar(
        """
        INSERT INTO historial_evolucion (
            villar_id, analisis_anterior_id, analisis_actual_id,
            resumen, comparacion, porcentajes_mejora
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            villar_id,
            analisis_anterior_id,
            analisis_actual_id,
            comparacion.get("resumen"),
            Json(comparacion),
            Json(cambio),
        ),
        retornar=True,
    )


def comparar_analisis(villar_id, analisis_anterior_id, analisis_actual_id, guardar=True):
    anterior = obtener_analisis_usuario(villar_id, analisis_anterior_id)
    actual = obtener_analisis_usuario(villar_id, analisis_actual_id)
    comparacion = construir_comparacion(anterior, actual)
    if guardar:
        comparacion["registro"] = guardar_comparacion(
            villar_id,
            analisis_anterior_id,
            analisis_actual_id,
            comparacion,
        )
    return comparacion


def obtener_resumen_evolucion(villar_id):
    analisis = consultar_todos(
        """
        SELECT * FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT 2
        """,
        (villar_id,),
    )
    if len(analisis) < 2:
        return {
            "hay_suficientes_datos": False,
            "mensaje": "Se necesitan al menos dos analisis para calcular evolucion.",
            "historial": analisis,
        }
    actual = analisis[0]
    anterior = analisis[1]
    comparacion = comparar_analisis(villar_id, anterior["id"], actual["id"], guardar=False)
    comparacion["hay_suficientes_datos"] = True
    comparacion["analisis_anterior"] = {
        "id": anterior.get("id"),
        "creado_en": anterior.get("creado_en"),
        "resumen_general": anterior.get("resumen_general"),
    }
    comparacion["analisis_actual"] = {
        "id": actual.get("id"),
        "creado_en": actual.get("creado_en"),
        "resumen_general": actual.get("resumen_general"),
    }
    return comparacion


def obtener_historial_evolucion(villar_id, limite=20):
    return consultar_todos(
        """
        SELECT * FROM historial_evolucion
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (villar_id, limite),
    )
