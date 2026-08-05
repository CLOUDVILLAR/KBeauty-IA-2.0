from copy import deepcopy

from base_datos.conexion import ejecutar
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


def _construir_rutina_manual(nombre_rutina):
    nombre_rutina = (nombre_rutina or "").strip()
    if not nombre_rutina:
        respuesta_error("Debes indicar el nombre de la rutina para el modo manual", 422)

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
            "seleccion": "manual",
        },
        "rutina": rutina,
        "productos": productos,
        "odoo_activo": odoo_esta_configurado(),
    }


def guardar_analisis_promotora(datos):
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
    ejecutar("UPDATE analisis_piel SET origen = 'promotora' WHERE id = %s", (analisis["id"],))
    analisis["origen"] = "promotora"

    modo_rutina = (datos.get("modo_rutina") or "automatica").strip().lower()
    if modo_rutina == "manual":
        recomendacion = _construir_rutina_manual(datos.get("rutina_nombre"))
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
