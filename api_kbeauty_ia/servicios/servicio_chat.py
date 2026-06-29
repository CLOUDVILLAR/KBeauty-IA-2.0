from psycopg2.extras import Json

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from base_datos.conexion import consultar_uno, consultar_todos, ejecutar
from servicios.servicio_openai import generar_respuesta_chat_kbeauty
from utilidades.respuestas import respuesta_error


def _json_seguro(valor):
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, UUID):
        return str(valor)
    if isinstance(valor, dict):
        return {str(k): _json_seguro(v) for k, v in valor.items()}
    if isinstance(valor, (list, tuple)):
        return [_json_seguro(v) for v in valor]
    return valor


def _recortar(valor, limite=900):
    if valor is None:
        return None
    texto = str(valor).strip()
    return texto[:limite] if texto else None


def _resumen_analisis(analisis, etiqueta):
    if not analisis:
        return None
    return {
        "etiqueta": etiqueta,
        "id": str(analisis.get("id")),
        "fecha": _json_seguro(analisis.get("creado_en")),
        "resumen_general": _recortar(analisis.get("resumen_general"), 1200),
        "tono_piel": analisis.get("tono_piel"),
        "condicion_principal_detectada": analisis.get("condicion_principal_detectada"),
        "condiciones_detectadas": analisis.get("condiciones_detectadas"),
        "puntajes": analisis.get("puntajes"),
        "recomendaciones_generales": (analisis.get("resultado_completo") or {}).get("recomendaciones_generales") if isinstance(analisis.get("resultado_completo"), dict) else None,
        "notas": (analisis.get("resultado_completo") or {}).get("notas") if isinstance(analisis.get("resultado_completo"), dict) else None,
    }


def obtener_mensajes_chat(villar_id, limite=200):
    return consultar_todos(
        """
        SELECT id, rol, contenido, creado_en
        FROM chat_ia_mensajes
        WHERE villar_id = %s
        ORDER BY creado_en ASC, id ASC
        LIMIT %s
        """,
        (villar_id, limite),
    )


def obtener_contexto_chat(villar_id):
    perfil = consultar_uno("SELECT * FROM perfiles_piel WHERE villar_id = %s", (villar_id,))

    primer_analisis = consultar_uno(
        """
        SELECT * FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en ASC
        LIMIT 1
        """,
        (villar_id,),
    )
    ultimos_analisis = consultar_todos(
        """
        SELECT * FROM analisis_piel
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT 2
        """,
        (villar_id,),
    )

    rutina = consultar_uno(
        """
        SELECT * FROM rutinas_recomendadas
        WHERE villar_id = %s
        ORDER BY creado_en DESC
        LIMIT 1
        """,
        (villar_id,),
    )
    productos = []
    if rutina:
        productos = consultar_todos(
            """
            SELECT nombre_producto, categoria, subtipo, momento, uso, frecuencia, descripcion_rutina, orden
            FROM productos_recomendados
            WHERE rutina_id = %s
            ORDER BY momento, orden
            """,
            (rutina["id"],),
        )

    ids_vistos = set()
    analisis_contexto = []
    if primer_analisis:
        ids_vistos.add(str(primer_analisis["id"]))
        analisis_contexto.append(_resumen_analisis(primer_analisis, "primer_analisis"))
    for indice, analisis in enumerate(ultimos_analisis, start=1):
        aid = str(analisis["id"])
        if aid in ids_vistos:
            continue
        ids_vistos.add(aid)
        analisis_contexto.append(_resumen_analisis(analisis, f"ultimo_{indice}"))

    return {
        "perfil_piel": _json_seguro(perfil),
        "analisis_incluidos": analisis_contexto,
        "rutina_actual": _json_seguro(rutina),
        "productos_rutina_actual": _json_seguro(productos),
        "regla_contexto": "Este chat usa solo el primer analisis hecho por el usuario y los dos ultimos analisis, ademas del perfil, tipo de piel y rutina actual.",
    }


def guardar_mensaje_chat(villar_id, rol, contenido, contexto_usado=None):
    return ejecutar(
        """
        INSERT INTO chat_ia_mensajes (villar_id, rol, contenido, contexto_usado)
        VALUES (%s, %s, %s, %s)
        RETURNING id, rol, contenido, creado_en
        """,
        (villar_id, rol, contenido, Json(_json_seguro(contexto_usado or {}))),
        retornar=True,
    )


def responder_chat(villar_id, mensaje):
    mensaje = (mensaje or "").strip()
    if not mensaje:
        respuesta_error("El mensaje no puede estar vacio", 422)
    if len(mensaje) > 3000:
        respuesta_error("El mensaje es demasiado largo", 422)

    contexto = obtener_contexto_chat(villar_id)
    historial = obtener_mensajes_chat(villar_id, limite=40)
    mensaje_guardado = guardar_mensaje_chat(villar_id, "user", mensaje)
    respuesta = generar_respuesta_chat_kbeauty(mensaje, contexto, historial)
    respuesta_guardada = guardar_mensaje_chat(villar_id, "assistant", respuesta, contexto)
    return {
        "mensaje_usuario": mensaje_guardado,
        "respuesta_ia": respuesta_guardada,
        "contexto_resumen": {
            "analisis_incluidos": [a for a in contexto["analisis_incluidos"] if a],
            "tipo_piel": (contexto.get("perfil_piel") or {}).get("tipo_piel"),
            "condicion_principal": (contexto.get("perfil_piel") or {}).get("condicion_principal"),
            "rutina": (contexto.get("rutina_actual") or {}).get("nombre_rutina"),
        },
    }
