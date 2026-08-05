from typing import List, Optional

from fastapi import APIRouter, Body, Depends, File, UploadFile

from dependencias.autenticacion_promotoras import verificar_clave_promotoras
from servicios.servicio_promotoras import (
    analizar_walkin,
    guardar_analisis_promotora,
    listar_rutinas_promotoras,
)
from utilidades.respuestas import respuesta_correcta, respuesta_error

router = APIRouter(prefix="/promotoras", tags=["promotoras"])


@router.get("/rutinas")
def ruta_listado_rutinas(autorizado=Depends(verificar_clave_promotoras)):
    return respuesta_correcta("Rutinas disponibles", listar_rutinas_promotoras())


@router.post("/analisis")
def ruta_analizar_walkin(
    frente: Optional[UploadFile] = File(None),
    lado_izquierdo: Optional[UploadFile] = File(None),
    lado_derecho: Optional[UploadFile] = File(None),
    imagenes: Optional[List[UploadFile]] = File(None),
    autorizado=Depends(verificar_clave_promotoras),
):
    if frente and lado_izquierdo and lado_derecho:
        archivos = [frente, lado_izquierdo, lado_derecho]
    elif imagenes and len(imagenes) == 3:
        archivos = imagenes
    else:
        respuesta_error(
            "Debes enviar 3 fotos: frente, lado_izquierdo y lado_derecho.",
            422,
        )

    resultado_ia = analizar_walkin(archivos)
    return respuesta_correcta("Analisis de IA generado", {"resultado_ia": resultado_ia})


@router.post("/guardar")
def ruta_guardar_analisis(datos: dict = Body(...), autorizado=Depends(verificar_clave_promotoras)):
    resultado = guardar_analisis_promotora(datos)
    return respuesta_correcta("Analisis de promotora guardado correctamente", resultado)
