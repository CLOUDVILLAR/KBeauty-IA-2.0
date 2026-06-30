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


# -----------------------------------------------------------------------------
# Fuentes de analisis para evolucion
# -----------------------------------------------------------------------------
# Evolucion debe comparar tanto los analisis normales de la app como los PDF
# presenciales subidos por empleados. Para no cambiar Flutter ni la base de
# datos, normalizamos ambas fuentes al mismo formato esperado por la comparacion:
# id, villar_id, resumen_general, puntajes, creado_en y tipo_analisis.


def _tabla_existe(nombre_tabla):
    fila = consultar_uno(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = %s
        ) AS existe
        """,
        (nombre_tabla,),
    )
    return bool(fila and fila.get("existe"))


def _columnas_tabla(nombre_tabla):
    filas = consultar_todos(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (nombre_tabla,),
    )
    return {fila["column_name"] for fila in filas}


def _normalizar_analisis_app(fila):
    if not fila:
        return None
    fila = dict(fila)
    fila["tipo_analisis"] = fila.get("tipo_analisis") or "app"
    fila["origen_evolucion"] = fila.get("origen_evolucion") or "analisis_piel"
    fila["puntajes"] = fila.get("puntajes") or {}
    return fila


def _normalizar_analisis_presencial(fila):
    if not fila:
        return None
    fila = dict(fila)
    valores = fila.get("valores_extraidos") or {}
    if not isinstance(valores, dict):
        valores = {}

    analisis_ia = valores.get("analisis_ia") or {}
    puntajes = valores.get("puntajes") or analisis_ia.get("puntajes") or {}

    fila["tipo_analisis"] = "presencial_pdf"
    fila["origen_evolucion"] = "analisis_presenciales_pdf"
    fila["puntajes"] = puntajes
    fila["resumen_general"] = (
        valores.get("resumen_general")
        or analisis_ia.get("resumen_general")
        or fila.get("titulo")
        or "Analisis presencial PDF"
    )
    fila["condicion_principal_detectada"] = (
        valores.get("condicion_principal_detectada")
        or analisis_ia.get("condicion_principal_detectada")
        or fila.get("condicion_principal_detectada")
    )
    fila["condiciones_detectadas"] = (
        valores.get("condiciones_detectadas")
        or analisis_ia.get("condiciones_detectadas")
        or []
    )
    fila["resultado_completo"] = valores
    return fila


def _consultar_analisis_presencial_usuario(villar_id, analisis_id=None, limite=None):
    if not _tabla_existe("analisis_presenciales_pdf"):
        return [] if limite else None

    columnas = _columnas_tabla("analisis_presenciales_pdf")
    if "valores_extraidos" not in columnas:
        return [] if limite else None

    parametros = []
    filtro_id = ""
    if analisis_id:
        filtro_id = "AND app.id = %s"

    limite_sql = ""
    if limite:
        limite_sql = "LIMIT %s"

    # Version nueva: la tabla presencial tiene villar_id directo.
    if "villar_id" in columnas:
        parametros.append(villar_id)
        if analisis_id:
            parametros.append(analisis_id)
        if limite:
            parametros.append(limite)

        sql = f"""
            SELECT app.*
            FROM analisis_presenciales_pdf app
            WHERE app.villar_id = %s
              {filtro_id}
              AND COALESCE(app.estado_procesamiento, 'completado') = 'completado'
              AND COALESCE(app.valores_extraidos, '{{}}'::jsonb) <> '{{}}'::jsonb
            ORDER BY app.creado_en DESC
            {limite_sql}
        """
    # Version vieja: relacion por usuarios.id.
    elif "usuario_id" in columnas:
        parametros.append(villar_id)
        if analisis_id:
            parametros.append(analisis_id)
        if limite:
            parametros.append(limite)

        sql = f"""
            SELECT app.*
            FROM analisis_presenciales_pdf app
            INNER JOIN usuarios u ON u.id = app.usuario_id
            WHERE u.villar_id = %s
              {filtro_id}
              AND COALESCE(app.estado_procesamiento, 'completado') = 'completado'
              AND COALESCE(app.valores_extraidos, '{{}}'::jsonb) <> '{{}}'::jsonb
            ORDER BY app.creado_en DESC
            {limite_sql}
        """
    else:
        return [] if limite else None

    if limite:
        return [_normalizar_analisis_presencial(fila) for fila in consultar_todos(sql, tuple(parametros))]

    fila = consultar_uno(sql, tuple(parametros))
    return _normalizar_analisis_presencial(fila)


def _consultar_ultimos_analisis_unificados(villar_id, limite=2):
    normales = consultar_todos(
        """
        SELECT *, 'app' AS tipo_analisis, 'analisis_piel' AS origen_evolucion
        FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (villar_id, limite),
    )
    normales = [_normalizar_analisis_app(fila) for fila in normales]

    presenciales = _consultar_analisis_presencial_usuario(villar_id, limite=limite) or []

    analisis = normales + presenciales
    analisis.sort(key=lambda item: item.get("creado_en"), reverse=True)
    return analisis[:limite]


def obtener_analisis_usuario(villar_id, analisis_id):
    analisis = consultar_uno(
        """
        SELECT *, 'app' AS tipo_analisis, 'analisis_piel' AS origen_evolucion
        FROM analisis_piel
        WHERE id = %s AND villar_id = %s
        """,
        (analisis_id, villar_id),
    )
    if analisis:
        return _normalizar_analisis_app(analisis)

    analisis_presencial = _consultar_analisis_presencial_usuario(villar_id, analisis_id=analisis_id)
    if analisis_presencial:
        return analisis_presencial

    respuesta_error("Analisis no encontrado", 404)


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

    comparacion["analisis_anterior"] = {
        "id": anterior.get("id"),
        "creado_en": anterior.get("creado_en"),
        "resumen_general": anterior.get("resumen_general"),
        "tipo_analisis": anterior.get("tipo_analisis"),
        "origen_evolucion": anterior.get("origen_evolucion"),
    }
    comparacion["analisis_actual"] = {
        "id": actual.get("id"),
        "creado_en": actual.get("creado_en"),
        "resumen_general": actual.get("resumen_general"),
        "tipo_analisis": actual.get("tipo_analisis"),
        "origen_evolucion": actual.get("origen_evolucion"),
    }

    # historial_evolucion en instalaciones existentes suele apuntar por FK a
    # analisis_piel. Para no romper comparaciones que incluyan PDF presencial,
    # solo guardamos automaticamente cuando ambos registros vienen de analisis_piel.
    if guardar:
        ambos_son_app = anterior.get("tipo_analisis") == "app" and actual.get("tipo_analisis") == "app"
        if ambos_son_app:
            comparacion["registro"] = guardar_comparacion(
                villar_id,
                analisis_anterior_id,
                analisis_actual_id,
                comparacion,
            )
        else:
            comparacion["registro"] = None
            comparacion["registro_guardado"] = False
            comparacion["nota_registro"] = "Comparacion calculada con PDF presencial. No se guardo en historial_evolucion para evitar romper relaciones antiguas con analisis_piel."

    return comparacion


def obtener_resumen_evolucion(villar_id):
    analisis = _consultar_ultimos_analisis_unificados(villar_id, limite=2)
    if len(analisis) < 2:
        return {
            "hay_suficientes_datos": False,
            "mensaje": "Se necesitan al menos dos analisis para calcular evolucion.",
            "historial": analisis,
        }

    actual = analisis[0]
    anterior = analisis[1]
    comparacion = construir_comparacion(anterior, actual)
    comparacion["hay_suficientes_datos"] = True
    comparacion["analisis_anterior"] = {
        "id": anterior.get("id"),
        "creado_en": anterior.get("creado_en"),
        "resumen_general": anterior.get("resumen_general"),
        "tipo_analisis": anterior.get("tipo_analisis"),
        "origen_evolucion": anterior.get("origen_evolucion"),
    }
    comparacion["analisis_actual"] = {
        "id": actual.get("id"),
        "creado_en": actual.get("creado_en"),
        "resumen_general": actual.get("resumen_general"),
        "tipo_analisis": actual.get("tipo_analisis"),
        "origen_evolucion": actual.get("origen_evolucion"),
    }
    comparacion["fuentes_incluidas"] = [
        "analisis_piel",
        "analisis_presenciales_pdf",
    ]
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
