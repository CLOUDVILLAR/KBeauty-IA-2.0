from fastapi import APIRouter, Depends, Query
from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_perfil import obtener_perfil_piel
from servicios.servicio_rutinas import obtener_resumen_rutinas, preparar_rutina_recomendada, buscar_texto_en_rutinas
from utilidades.respuestas import respuesta_correcta, respuesta_error

router = APIRouter(prefix="/rutinas", tags=["rutinas"])


@router.get("/listado")
def ruta_listado_rutinas(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Rutinas disponibles", obtener_resumen_rutinas())


@router.get("/buscar")
def ruta_buscar_rutinas(texto: str = Query(...), usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Resultados de busqueda", buscar_texto_en_rutinas(texto))


@router.get("/recomendada")
def ruta_rutina_recomendada(usuario=Depends(obtener_usuario_actual)):
    perfil = obtener_perfil_piel(usuario["villar_id"])
    if not perfil:
        respuesta_error("Debes completar el formulario inicial", 403)
    recomendacion = preparar_rutina_recomendada(perfil, {}, incluir_odoo=True)
    return respuesta_correcta("Rutina recomendada", recomendacion)
