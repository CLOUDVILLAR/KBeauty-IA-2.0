from fastapi import APIRouter, Body, Depends
from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_usuarios import crear_usuario, iniciar_sesion, listar_roles, refrescar_sesion, cerrar_sesion
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/usuarios", tags=["usuarios"])


@router.post("/registro")
def ruta_registro(datos: dict = Body(...)):
    resultado = crear_usuario(datos)
    return respuesta_correcta("Usuario creado en Villar.do y vinculado a KBeauty", resultado)


@router.post("/login")
def ruta_login(datos: dict = Body(...)):
    resultado = iniciar_sesion(datos)
    return respuesta_correcta("Sesion iniciada con Villar.do", resultado)


@router.post("/refresh")
def ruta_refresh(datos: dict = Body(...)):
    resultado = refrescar_sesion(datos)
    return respuesta_correcta("Sesion renovada con Villar.do", resultado)


@router.post("/logout")
def ruta_logout(datos: dict = Body(default={})):
    resultado = cerrar_sesion(datos)
    return respuesta_correcta("Sesion cerrada", resultado)


@router.get("/perfil")
def ruta_perfil(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Perfil del usuario KBeauty + Villar.do", usuario)


@router.get("/roles")
def ruta_roles(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Roles locales de KBeauty", listar_roles())
