from copy import deepcopy

from base_datos.conexion import consultar_todos, consultar_uno, ejecutar
from servicios.servicio_analisis import guardar_analisis, guardar_rutina_recomendada
from servicios.servicio_odoo import odoo_esta_configurado
from servicios.servicio_openai import analizar_imagenes_piel
from servicios.servicio_rutinas import (
    agregar_ubicaciones_a_rutina,
    listar_rutinas,
    obtener_productos_de_rutina,
    obtener_resumen_rutinas,
    preparar_rutina_recomendada,
)
from servicios.servicio_usuarios import asegurar_usuario_local
from servicios.servicio_villar_do import resolver_cliente_villar_do
from utilidades.imagenes import leer_y_normalizar_imagenes
from utilidades.respuestas import respuesta_error


def listar_rutinas_promotoras():
    return obtener_resumen_rutinas()


def analizar_walkin(archivos):
    imagenes = leer_y_normalizar_imagenes(archivos, cantidad_requerida=3)
    return analizar_imagenes_piel(imagenes)


def _construir_rutina_por_nombre(nombre_rutina):
    coincidencia = next(
        (rutina for rutina in listar_rutinas() if rutina.get("nombre") == nombre_rutina),
        None,
    )
    if not coincidencia:
        respuesta_error("Rutina no encontrada", 404)

    rutina = agregar_ubicaciones_a_rutina(deepcopy(coincidencia))
    productos = obtener_productos_de_rutina(rutina)

    return {
        "nombre_rutina": rutina.get("nombre"),
        "tipo_piel": rutina.get("tipo_piel"),
        "condicion": rutina.get("condicion"),
        "criterios": {
            "tipo_piel": rutina.get("tipo_piel"),
            "condicion": rutina.get("condicion"),
            "seleccion": "confirmada_por_promotora",
        },
        "rutina": rutina,
        "productos": productos,
        "odoo_activo": odoo_esta_configurado(),
    }


def guardar_analisis_promotora(datos, ip_origen=None):
    nombre = (datos.get("cliente_nombre") or "").strip()
    telefono = (datos.get("cliente_telefono") or "").strip()
    if not nombre or not telefono:
        respuesta_error("Nombre y telefono del cliente son obligatorios", 422)

    resultado_ia = datos.get("resultado_ia") or {}
    if not resultado_ia:
        respuesta_error("Falta el resultado del analisis de IA", 422)

    resultado_villar = resolver_cliente_villar_do(
        nombre, (datos.get("cliente_apellido") or "").strip(), telefono
    )
    villar_id = (resultado_villar or {}).get("villar_id")
    if not villar_id:
        respuesta_error("No se pudo resolver el cliente en Villar.do", 502)

    asegurar_usuario_local(villar_id, resultado_villar)

    analisis = guardar_analisis(villar_id, resultado_ia)
    ejecutar(
        """
        UPDATE analisis_piel
        SET origen = 'promotora', cliente_nombre = %s, cliente_telefono = %s, ip_origen = %s
        WHERE id = %s
        """,
        (nombre, telefono, ip_origen, analisis["id"]),
    )
    analisis["origen"] = "promotora"
    analisis["cliente_nombre"] = nombre
    analisis["cliente_telefono"] = telefono
    analisis["ip_origen"] = ip_origen

    # Si la promotora confirma la rutina (por nombre, de la lista del JSON) se
    # usa esa tal cual. Si no sabe ("No lo se"), la condicion y el tipo de
    # piel salen del mismo analisis de fotos.
    rutina_nombre = (datos.get("rutina_nombre") or "").strip()
    if rutina_nombre:
        recomendacion = _construir_rutina_por_nombre(rutina_nombre)
    else:
        perfil_sintetico = {
            "tipo_piel": resultado_ia.get("tipo_piel_estimado"),
            "condicion_principal": resultado_ia.get("condicion_principal_detectada"),
        }
        recomendacion = preparar_rutina_recomendada(perfil_sintetico, resultado_ia, incluir_odoo=True)

    rutina_guardada = guardar_rutina_recomendada(villar_id, analisis["id"], recomendacion)

    return {
        "analisis": analisis,
        "resultado_ia": resultado_ia,
        "rutina_recomendada": recomendacion,
        "rutina_guardada": rutina_guardada,
        "villar_id": villar_id,
    }


def obtener_historial_promotoras(limite=50):
    return consultar_todos(
        """
        SELECT id, creado_en, cliente_nombre, cliente_telefono,
               resumen_general, tono_piel, condicion_principal_detectada
        FROM analisis_piel
        WHERE origen = 'promotora'
        ORDER BY creado_en DESC
        LIMIT %s
        """,
        (limite,),
    )


def obtener_detalle_analisis_promotora(analisis_id):
    analisis = consultar_uno(
        "SELECT * FROM analisis_piel WHERE id = %s AND origen = 'promotora'",
        (analisis_id,),
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
