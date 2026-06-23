from fastapi import APIRouter, Body, Depends
from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_perfil import guardar_formulario, obtener_estado_perfil, obtener_perfil_piel, obtener_opciones_formulario
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/perfil", tags=["perfil"])


@router.get("/opciones")
def ruta_opciones_formulario():
    return respuesta_correcta("Opciones del formulario", obtener_opciones_formulario())


@router.get("/estado")
def ruta_estado(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Estado del perfil", obtener_estado_perfil(usuario))


@router.get("/formulario")
def ruta_obtener_formulario(usuario=Depends(obtener_usuario_actual)):
    perfil = obtener_perfil_piel(usuario["villar_id"])
    return respuesta_correcta("Formulario del perfil", perfil)


@router.post("/formulario")
def ruta_guardar_formulario(datos: dict = Body(...), usuario=Depends(obtener_usuario_actual)):
    perfil = guardar_formulario(usuario["villar_id"], datos)
    return respuesta_correcta("Formulario guardado correctamente", perfil)
