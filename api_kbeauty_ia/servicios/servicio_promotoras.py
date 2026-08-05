from base_datos.conexion import ejecutar
from servicios.servicio_analisis import guardar_analisis, guardar_rutina_recomendada
from servicios.servicio_openai import analizar_imagenes_piel
from servicios.servicio_rutinas import preparar_rutina_recomendada
from servicios.servicio_usuarios import asegurar_usuario_local
from servicios.servicio_villar_do import resolver_cliente_villar_do
from utilidades.imagenes import leer_y_normalizar_imagenes
from utilidades.respuestas import respuesta_error


def analizar_walkin(archivos):
    imagenes = leer_y_normalizar_imagenes(archivos, cantidad_requerida=3)
    return analizar_imagenes_piel(imagenes)


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

    # La condicion siempre sale del analisis de fotos. El tipo de piel lo
    # confirma la promotora si lo sabe; si no, se usa el estimado por la IA.
    tipo_piel_elegido = (datos.get("tipo_piel_seleccionado") or "").strip() or None
    perfil_sintetico = {
        "tipo_piel": tipo_piel_elegido or resultado_ia.get("tipo_piel_estimado"),
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
