from fastapi import APIRouter, Depends
from dependencias.autenticacion import obtener_usuario_actual
from servicios.servicio_odoo import buscar_producto_por_id, obtener_ubicaciones_producto, odoo_esta_configurado
from utilidades.respuestas import respuesta_correcta

router = APIRouter(prefix="/odoo", tags=["odoo"])


@router.get("/estado")
def ruta_estado_odoo(usuario=Depends(obtener_usuario_actual)):
    return respuesta_correcta("Estado de Odoo", {"odoo_activo": odoo_esta_configurado()})


@router.get("/producto/{id_odoo}")
def ruta_producto_odoo(id_odoo: int, usuario=Depends(obtener_usuario_actual)):
    producto = buscar_producto_por_id(id_odoo)
    ubicaciones = obtener_ubicaciones_producto(id_odoo)
    return respuesta_correcta("Producto de Odoo", {"producto": producto, "ubicaciones": ubicaciones})
