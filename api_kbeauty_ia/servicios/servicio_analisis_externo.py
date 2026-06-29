from copy import deepcopy
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from psycopg2.extras import Json
from pypdf import PdfReader

from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from servicios.servicio_openai import analizar_pdf_externo_piel
from servicios.servicio_rutinas import (
    agregar_ubicaciones_a_rutina,
    cargar_rutinas,
    obtener_productos_de_rutina,
    obtener_resumen_rutinas,
    buscar_rutina_por_tipo_y_condicion,
)
from utilidades.normalizacion import normalizar_texto
from utilidades.respuestas import respuesta_error


def _json_seguro(valor):
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    if isinstance(valor, UUID):
        return str(valor)
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, dict):
        return {str(k): _json_seguro(v) for k, v in valor.items()}
    if isinstance(valor, (list, tuple)):
        return [_json_seguro(v) for v in valor]
    return valor


def extraer_texto_pdf(archivo_pdf):
    nombre = (archivo_pdf.filename or "analisis_externo.pdf").strip()
    if not nombre.lower().endswith(".pdf"):
        respuesta_error("Debes subir un archivo PDF", 422)

    try:
        lector = PdfReader(archivo_pdf.file)
        textos = []
        for indice, pagina in enumerate(lector.pages):
            if indice >= 15:
                break
            texto = pagina.extract_text() or ""
            if texto.strip():
                textos.append(texto.strip())
    except Exception as exc:
        respuesta_error("No se pudo leer el PDF externo", 422, {"error": str(exc)[:300]})

    texto_final = "\n\n".join(textos).strip()
    if len(texto_final) < 40:
        respuesta_error("El PDF no tiene texto legible suficiente. Si es un PDF escaneado como imagen, primero exportalo con texto/OCR.", 422)
    return texto_final[:50000]


def _buscar_rutina_por_nombre(nombre):
    if not nombre:
        return None
    objetivo = normalizar_texto(nombre)
    rutinas = cargar_rutinas().get("rutinas_por_piel", [])
    for rutina in rutinas:
        if normalizar_texto(rutina.get("nombre")) == objetivo:
            return deepcopy(rutina)
    for rutina in rutinas:
        if objetivo and objetivo in normalizar_texto(rutina.get("nombre")):
            return deepcopy(rutina)
    return None


def _preparar_rutina_desde_ia(analisis_ia):
    rutina = _buscar_rutina_por_nombre(analisis_ia.get("rutina_recomendada_nombre"))
    if rutina:
        rutina = agregar_ubicaciones_a_rutina(rutina)
        productos = obtener_productos_de_rutina(rutina)
        return {
            "nombre_rutina": rutina.get("nombre") or analisis_ia.get("rutina_recomendada_nombre"),
            "tipo_piel": rutina.get("tipo_piel") or analisis_ia.get("tipo_piel_estimado"),
            "condicion": rutina.get("condicion") or analisis_ia.get("condicion_principal_detectada"),
            "criterios": {
                "origen": "analisis_externo_pdf",
                "tipo_piel_ia": analisis_ia.get("tipo_piel_estimado"),
                "condicion_ia": analisis_ia.get("condicion_principal_detectada"),
                "rutina_elegida_por_ia": analisis_ia.get("rutina_recomendada_nombre"),
            },
            "rutina": rutina,
            "productos": productos,
            "razon_rutina": analisis_ia.get("razon_rutina"),
        }

    # Fallback solo con datos del PDF: tipo de piel y condicion detectados por la IA.
    # No usa perfil, rutina actual, historial ni evolucion del usuario.
    rutina = buscar_rutina_por_tipo_y_condicion(
        analisis_ia.get("tipo_piel_estimado"),
        analisis_ia.get("condicion_principal_detectada"),
    )
    if rutina:
        rutina = agregar_ubicaciones_a_rutina(rutina)
    productos = obtener_productos_de_rutina(rutina)
    return {
        "nombre_rutina": (rutina or {}).get("nombre") or "Rutina recomendada",
        "tipo_piel": (rutina or {}).get("tipo_piel") or analisis_ia.get("tipo_piel_estimado") or "N/D",
        "condicion": (rutina or {}).get("condicion") or analisis_ia.get("condicion_principal_detectada") or "N/D",
        "criterios": {
            "origen": "analisis_externo_pdf_fallback_solo_pdf",
            "tipo_piel_ia": analisis_ia.get("tipo_piel_estimado"),
            "condicion_ia": analisis_ia.get("condicion_principal_detectada"),
            "rutina_elegida_por_ia": analisis_ia.get("rutina_recomendada_nombre"),
        },
        "rutina": rutina,
        "productos": productos,
        "razon_rutina": analisis_ia.get("razon_rutina") or "Se eligio la rutina mas cercana usando solo los datos extraidos del PDF.",
    }


def guardar_analisis_externo(villar_id, nombre_archivo, texto_extraido, analisis_ia, rutina_recomendada):
    proveedor = analisis_ia.get("proveedor_detectado") or "N/D"
    return ejecutar(
        """
        INSERT INTO analisis_externos (
            villar_id, proveedor, nombre_archivo, texto_extraido,
            datos_extraidos, analisis_ia, rutina_recomendada
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            villar_id,
            proveedor,
            nombre_archivo,
            texto_extraido[:50000],
            Json(_json_seguro({
                "metricas_clave": analisis_ia.get("metricas_clave") or [],
                "puntajes": analisis_ia.get("puntajes") or {},
                "condiciones_detectadas": analisis_ia.get("condiciones_detectadas") or [],
            })),
            Json(_json_seguro(analisis_ia)),
            Json(_json_seguro(rutina_recomendada)),
        ),
        retornar=True,
    )


def importar_analisis_externo(usuario, archivo_pdf):
    # Este modulo externo trabaja exclusivamente con la informacion del PDF.
    # No lee perfil, tipo de piel guardado, rutina actual, historial ni evolucion.
    texto_pdf = extraer_texto_pdf(archivo_pdf)
    analisis_ia = analizar_pdf_externo_piel(texto_pdf, obtener_resumen_rutinas())
    rutina_recomendada = _preparar_rutina_desde_ia(analisis_ia)
    registro = guardar_analisis_externo(
        usuario["villar_id"],
        archivo_pdf.filename or "analisis_externo.pdf",
        texto_pdf,
        analisis_ia,
        rutina_recomendada,
    )

    return {
        "analisis_externo": registro,
        "analisis_ia": analisis_ia,
        "rutina_recomendada": rutina_recomendada,
    }


def obtener_historial_analisis_externo(villar_id, limite=20):
    return consultar_todos(
        """
        SELECT id, proveedor, nombre_archivo, datos_extraidos, analisis_ia,
               rutina_recomendada, aplicado_a_rutina, creado_en
        FROM analisis_externos
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (villar_id, limite),
    )


def obtener_detalle_analisis_externo(villar_id, analisis_externo_id):
    detalle = consultar_uno(
        """
        SELECT *
        FROM analisis_externos
        WHERE id = %s AND villar_id = %s
        """,
        (analisis_externo_id, villar_id),
    )
    if not detalle:
        respuesta_error("Analisis externo no encontrado", 404)
    return detalle
