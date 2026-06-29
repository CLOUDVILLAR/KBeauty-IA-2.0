from fastapi import APIRouter, Depends, File, Query, UploadFile

from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_analisis_externo import (
    importar_analisis_externo,
    obtener_detalle_analisis_externo,
    obtener_historial_analisis_externo,
)
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/analisis-externos", tags=["analisis externos"])


@router.post("/importar")
def ruta_importar_analisis_externo(
    pdf: UploadFile = File(...),
    usuario=Depends(obtener_usuario_actual),
):
    resultado = importar_analisis_externo(usuario, pdf)
    return respuesta_correcta("Analisis externo importado correctamente", resultado)


@router.get("/historial")
def ruta_historial_analisis_externo(
    limite: int = Query(20, ge=1, le=100),
    usuario=Depends(obtener_usuario_actual),
):
    historial = obtener_historial_analisis_externo(usuario["villar_id"], limite)
    return respuesta_correcta("Historial de analisis externos", historial)


@router.get("/{analisis_externo_id}")
def ruta_detalle_analisis_externo(
    analisis_externo_id: str,
    usuario=Depends(obtener_usuario_actual),
):
    detalle = obtener_detalle_analisis_externo(usuario["villar_id"], analisis_externo_id)
    return respuesta_correcta("Detalle de analisis externo", detalle)
