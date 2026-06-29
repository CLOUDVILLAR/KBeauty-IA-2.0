from fastapi import APIRouter, Body, Depends, Query

from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_chat import obtener_mensajes_chat, responder_chat, obtener_contexto_chat
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/chat", tags=["chat"])


@router.get("/mensajes")
def ruta_mensajes_chat(limite: int = Query(200, ge=1, le=500), usuario=Depends(obtener_usuario_actual)):
    mensajes = obtener_mensajes_chat(usuario["villar_id"], limite)
    return respuesta_correcta("Chat IA", {"mensajes": mensajes})


@router.get("/contexto")
def ruta_contexto_chat(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Contexto del chat IA", obtener_contexto_chat(usuario["villar_id"]))


@router.post("/mensaje")
def ruta_enviar_mensaje_chat(datos: dict = Body(...), usuario=Depends(obtener_usuario_actual)):
    resultado = responder_chat(usuario["villar_id"], datos.get("mensaje"))
    return respuesta_correcta("Respuesta generada", resultado)
