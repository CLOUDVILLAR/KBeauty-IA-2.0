from psycopg2.extras import Json

from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from utilidades.imagenes import leer_y_normalizar_imagenes
from utilidades.respuestas import respuesta_error
from servicios.servicio_openai import analizar_imagenes_piel
from servicios.servicio_perfil import obtener_perfil_piel
from servicios.servicio_rutinas import preparar_rutina_recomendada, obtener_productos_de_rutina
from config.configuracion import obtener_configuracion


def _texto_seguro_bd(valor):
    """Convierte valores anidados a texto antes de guardarlos en columnas TEXT."""
    if valor is None:
        return None
    if isinstance(valor, str):
        texto = valor.strip()
        return texto or None
    if isinstance(valor, (int, float, bool)):
        return str(valor)
    if isinstance(valor, list):
        partes = [_texto_seguro_bd(item) for item in valor]
        partes = [item for item in partes if item]
        return ", ".join(partes) if partes else None
    if isinstance(valor, dict):
        # Prioriza los textos mas utiles de los JSON de rutina/productos.
        for clave in (
            "texto", "descripcion", "descripcion_rutina", "detalle", "uso",
            "paso_rutina", "dia", "día", "noche", "manana", "mañana",
            "frecuencia", "instruccion", "instrucciones", "valor", "nombre",
        ):
            if clave in valor:
                texto = _texto_seguro_bd(valor.get(clave))
                if texto:
                    return texto
        partes = []
        for clave, item in valor.items():
            texto = _texto_seguro_bd(item)
            if texto:
                partes.append(f"{clave}: {texto}")
        return "; ".join(partes) if partes else None
    return str(valor)


def verificar_formulario_completado(usuario):
    perfil = obtener_perfil_piel(usuario["villar_id"])
    if not usuario.get("formulario_completado") or not perfil:
        respuesta_error("Debes completar el formulario inicial antes de analizar tu piel", 403)
    return perfil


def guardar_analisis(villar_id, resultado_ia):
    puntajes = resultado_ia.get("puntajes") or {}
    configuracion = obtener_configuracion()
    analisis = ejecutar(
        """
        INSERT INTO analisis_piel (
            villar_id, resumen_general, tono_piel,
            condicion_principal_detectada, condiciones_detectadas,
            puntajes, resultado_completo, modo_demo, modelo_ia, version_rubrica
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            villar_id,
            resultado_ia.get("resumen_general"),
            resultado_ia.get("tono_piel"),
            resultado_ia.get("condicion_principal_detectada"),
            Json(resultado_ia.get("condiciones_detectadas") or []),
            Json(puntajes),
            Json(resultado_ia),
            False,
            configuracion.get("openai_modelo"),
            resultado_ia.get("version_rubrica") or "kbeauty-v1",
        ),
        retornar=True,
    )
    guardar_zonas_analisis(analisis["id"], resultado_ia.get("zonas") or {})
    return analisis


def guardar_zonas_analisis(analisis_id, zonas):
    for nombre_zona, datos_zona in zonas.items():
        ejecutar(
            """
            INSERT INTO analisis_zonas (analisis_id, zona, resumen, puntajes)
            VALUES (%s, %s, %s, %s)
            """,
            (
                analisis_id,
                nombre_zona,
                datos_zona.get("resumen"),
                Json(datos_zona),
            ),
        )


def guardar_rutina_recomendada(villar_id, analisis_id, recomendacion):
    rutina = recomendacion.get("rutina") or {}
    criterios = recomendacion.get("criterios") or {}
    registro = ejecutar(
        """
        INSERT INTO rutinas_recomendadas (
            villar_id, analisis_id, nombre_rutina, tipo_piel, condicion, criterios, rutina
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            villar_id,
            analisis_id,
            recomendacion.get("nombre_rutina") or rutina.get("nombre"),
            recomendacion.get("tipo_piel") or criterios.get("tipo_piel"),
            recomendacion.get("condicion") or criterios.get("condicion"),
            Json(criterios),
            Json(rutina),
        ),
        retornar=True,
    )

    productos = obtener_productos_de_rutina(rutina)
    for producto in productos:
        ejecutar(
            """
            INSERT INTO productos_recomendados (
                rutina_id, id_odoo, nombre_producto, categoria, subtipo, momento,
                uso, frecuencia, descripcion_rutina, orden, ubicaciones_odoo, odoo_activo
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                registro["id"],
                producto.get("id_odoo"),
                producto.get("nombre_producto"),
                producto.get("categoria"),
                producto.get("subtipo"),
                producto.get("momento"),
                _texto_seguro_bd(producto.get("uso")),
                _texto_seguro_bd(producto.get("frecuencia")),
                _texto_seguro_bd(producto.get("descripcion_rutina")),
                producto.get("orden") or 0,
                Json(producto.get("ubicaciones_odoo") or []),
                bool(producto.get("odoo_activo")),
            ),
        )
    return registro


def leer_imagenes_temporales(archivos):
    return leer_y_normalizar_imagenes(archivos, cantidad_requerida=3)


def crear_nuevo_analisis(usuario, archivos):
    perfil = verificar_formulario_completado(usuario)
    imagenes = leer_imagenes_temporales(archivos)
    resultado_ia = analizar_imagenes_piel(imagenes)

    villar_id = usuario["villar_id"]
    analisis = guardar_analisis(villar_id, resultado_ia)
    recomendacion = preparar_rutina_recomendada(perfil, resultado_ia, incluir_odoo=True)
    rutina_guardada = guardar_rutina_recomendada(villar_id, analisis["id"], recomendacion)

    return {
        "analisis": analisis,
        "resultado_ia": resultado_ia,
        "rutina_recomendada": recomendacion,
        "rutina_guardada": rutina_guardada,
    }


def obtener_historial(villar_id, limite=20):
    return consultar_todos(
        """
        SELECT id, creado_en, resumen_general, tono_piel,
               condicion_principal_detectada, condiciones_detectadas,
               puntajes, resultado_completo, modo_demo, modelo_ia, version_rubrica
        FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (villar_id, limite),
    )


def obtener_detalle_analisis(villar_id, analisis_id):
    analisis = consultar_uno(
        """
        SELECT * FROM analisis_piel
        WHERE id = %s AND villar_id = %s
        """,
        (analisis_id, villar_id),
    )
    if not analisis:
        respuesta_error("Analisis no encontrado", 404)

    zonas = consultar_todos(
        "SELECT * FROM analisis_zonas WHERE analisis_id = %s ORDER BY zona",
        (analisis_id,),
    )
    rutina = consultar_uno(
        "SELECT * FROM rutinas_recomendadas WHERE analisis_id = %s ORDER BY creado_en DESC LIMIT 1",
        (analisis_id,),
    )
    productos = []
    if rutina:
        productos = consultar_todos(
            "SELECT * FROM productos_recomendados WHERE rutina_id = %s ORDER BY momento, orden",
            (rutina["id"],),
        )
    return {"analisis": analisis, "zonas": zonas, "rutina": rutina, "productos": productos}
