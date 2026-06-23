from psycopg2.extras import Json
from base_datos.conexion import consultar_uno, ejecutar
from utilidades.validaciones import validar_campos, limpiar_texto
from utilidades.normalizacion import normalizar_tipo_piel, normalizar_condicion
from utilidades.respuestas import respuesta_error

TIPOS_PIEL = ["seca", "grasa", "mixta", "normal", "sensible"]
CONDICIONES = ["none", "melasma", "manchas", "acne", "arrugas", "opaca", "anti-age"]
RANGOS_EDAD = ["13-17", "18-24", "25-34", "35-44", "45-54", "55+"]


def obtener_opciones_formulario():
    return {
        "tipos_piel": TIPOS_PIEL,
        "condiciones": CONDICIONES,
        "rangos_edad": RANGOS_EDAD,
        "niveles_sensibilidad": ["baja", "media", "alta"],
    }


def validar_datos_perfil(datos):
    validar_campos(datos, ["tipo_piel", "condicion_principal", "rango_edad"])
    tipo_piel = normalizar_tipo_piel(datos.get("tipo_piel"))
    condicion = normalizar_condicion(datos.get("condicion_principal"))
    rango_edad = limpiar_texto(datos.get("rango_edad"))
    sensibilidad = limpiar_texto(datos.get("sensibilidad") or "media").lower()

    if tipo_piel not in TIPOS_PIEL:
        respuesta_error("Tipo de piel no permitido", 422, {"opciones": TIPOS_PIEL})
    if condicion not in CONDICIONES:
        respuesta_error("Condicion no permitida", 422, {"opciones": CONDICIONES})
    if rango_edad not in RANGOS_EDAD:
        respuesta_error("Rango de edad no permitido", 422, {"opciones": RANGOS_EDAD})
    if sensibilidad not in ["baja", "media", "alta"]:
        respuesta_error("Sensibilidad no permitida", 422)

    alergias = datos.get("alergias")
    if isinstance(alergias, list):
        alergias = ", ".join([str(x) for x in alergias if str(x).strip()])

    return {
        "tipo_piel": tipo_piel,
        "condicion_principal": condicion,
        "rango_edad": rango_edad,
        "sensibilidad": sensibilidad,
        "usa_protector_solar": bool(datos.get("usa_protector_solar", False)),
        "frecuencia_protector_solar": limpiar_texto(datos.get("frecuencia_protector_solar")),
        "alergias": limpiar_texto(alergias),
        "productos_actuales": limpiar_texto(datos.get("productos_actuales") or datos.get("rutina_actual")),
        "objetivo_principal": limpiar_texto(datos.get("objetivo_principal")),
    }


def obtener_perfil_piel(villar_id):
    return consultar_uno("SELECT * FROM perfiles_piel WHERE villar_id = %s", (villar_id,))


def guardar_formulario(villar_id, datos):
    datos_limpios = validar_datos_perfil(datos)
    perfil_actual = obtener_perfil_piel(villar_id)
    if perfil_actual:
        perfil = ejecutar(
            """
            UPDATE perfiles_piel
            SET tipo_piel = %s,
                condicion_principal = %s,
                rango_edad = %s,
                sensibilidad = %s,
                usa_protector_solar = %s,
                frecuencia_protector_solar = %s,
                alergias = %s,
                productos_actuales = %s,
                objetivo_principal = %s,
                actualizado_en = NOW()
            WHERE villar_id = %s
            RETURNING *
            """,
            (
                datos_limpios["tipo_piel"],
                datos_limpios["condicion_principal"],
                datos_limpios["rango_edad"],
                datos_limpios["sensibilidad"],
                datos_limpios["usa_protector_solar"],
                datos_limpios["frecuencia_protector_solar"],
                datos_limpios["alergias"],
                datos_limpios["productos_actuales"],
                datos_limpios["objetivo_principal"],
                villar_id,
            ),
            retornar=True,
        )
    else:
        perfil = ejecutar(
            """
            INSERT INTO perfiles_piel (
                villar_id, tipo_piel, condicion_principal, rango_edad,
                sensibilidad, usa_protector_solar, frecuencia_protector_solar,
                alergias, productos_actuales, objetivo_principal
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
            """,
            (
                villar_id,
                datos_limpios["tipo_piel"],
                datos_limpios["condicion_principal"],
                datos_limpios["rango_edad"],
                datos_limpios["sensibilidad"],
                datos_limpios["usa_protector_solar"],
                datos_limpios["frecuencia_protector_solar"],
                datos_limpios["alergias"],
                datos_limpios["productos_actuales"],
                datos_limpios["objetivo_principal"],
            ),
            retornar=True,
        )

    ejecutar(
        "UPDATE usuarios SET formulario_completado = true, actualizado_en = NOW() WHERE villar_id = %s",
        (villar_id,),
    )
    return perfil


def obtener_estado_perfil(usuario):
    perfil = obtener_perfil_piel(usuario["villar_id"])
    return {
        "formulario_completado": bool(usuario.get("formulario_completado")) and perfil is not None,
        "perfil": perfil,
    }
