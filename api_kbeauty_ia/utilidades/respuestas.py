from fastapi import HTTPException


def respuesta_correcta(mensaje="Operacion completada", datos=None):
    return {
        "correcto": True,
        "mensaje": mensaje,
        "datos": datos if datos is not None else {},
    }


def respuesta_error(mensaje="Ocurrio un error", codigo=400, detalles=None):
    raise HTTPException(
        status_code=codigo,
        detail={
            "correcto": False,
            "mensaje": mensaje,
            "detalles": detalles or {},
        },
    )
