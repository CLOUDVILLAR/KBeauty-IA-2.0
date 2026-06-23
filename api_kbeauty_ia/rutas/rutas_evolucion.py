from fastapi import APIRouter, Depends, Body, Query
from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_evolucion import obtener_resumen_evolucion, obtener_historial_evolucion, comparar_analisis
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/evolucion", tags=["evolucion"])


@router.get("/resumen")
def ruta_resumen(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Resumen de evolucion", obtener_resumen_evolucion(usuario["villar_id"]))


@router.get("/historial")
def ruta_historial(limite: int = Query(20, ge=1, le=100), usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Historial de evolucion", obtener_historial_evolucion(usuario["villar_id"], limite))


@router.post("/comparar")
def ruta_comparar(datos: dict = Body(...), usuario=Depends(obtener_usuario_actual)):
    comparacion = comparar_analisis(
        usuario["villar_id"],
        datos.get("analisis_anterior_id"),
        datos.get("analisis_actual_id"),
        guardar=bool(datos.get("guardar", True)),
    )
    return respuesta_correcta("Comparacion generada", comparacion)
