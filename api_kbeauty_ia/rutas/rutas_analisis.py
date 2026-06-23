from typing import List, Optional
from fastapi import APIRouter, Depends, File, UploadFile, Query

from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_analisis import crear_nuevo_analisis, obtener_historial, obtener_detalle_analisis
from utilidades.respuestas import respuesta_correcta, respuesta_error

router = APIRouter(prefix="/analisis", tags=["analisis"])


def ordenar_archivos_recibidos(frente, lado_izquierdo, lado_derecho, imagenes):
    if frente and lado_izquierdo and lado_derecho:
        return [frente, lado_izquierdo, lado_derecho]
    if imagenes and len(imagenes) == 3:
        return imagenes
    respuesta_error(
        "Debes enviar 3 fotos: frente, lado_izquierdo y lado_derecho. Tambien puedes enviar una lista llamada imagenes con 3 archivos.",
        422,
    )


@router.post("/nuevo")
def ruta_nuevo_analisis(
    frente: Optional[UploadFile] = File(None),
    lado_izquierdo: Optional[UploadFile] = File(None),
    lado_derecho: Optional[UploadFile] = File(None),
    imagenes: Optional[List[UploadFile]] = File(None),
    usuario=Depends(obtener_usuario_actual),
):
    archivos = ordenar_archivos_recibidos(frente, lado_izquierdo, lado_derecho, imagenes)
    resultado = crear_nuevo_analisis(usuario, archivos)
    return respuesta_correcta("Analisis creado correctamente", resultado)


@router.get("/historial")
def ruta_historial(limite: int = Query(20, ge=1, le=100), usuario=Depends(obtener_usuario_actual)):
    historial = obtener_historial(usuario["villar_id"], limite)
    return respuesta_correcta("Historial de analisis", historial)


@router.get("/{analisis_id}")
def ruta_detalle_analisis(analisis_id: str, usuario=Depends(obtener_usuario_actual)):
    detalle = obtener_detalle_analisis(usuario["villar_id"], analisis_id)
    return respuesta_correcta("Detalle del analisis", detalle)
