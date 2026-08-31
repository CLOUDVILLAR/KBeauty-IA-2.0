from copy import deepcopy

from base_datos.conexion import consultar_todos, consultar_uno, ejecutar
from servicios.servicio_analisis import guardar_analisis, guardar_rutina_recomendada
from servicios.servicio_odoo import odoo_esta_configurado
from servicios.servicio_openai import analizar_imagenes_piel
from servicios.servicio_rutinas import (
    agregar_ubicaciones_a_rutina,
    listar_rutinas,
    obtener_productos_de_rutina,
    obtener_resumen_rutinas,
    preparar_rutina_recomendada,
)
from servicios.servicio_usuarios import asegurar_usuario_local
from servicios.servicio_villar_do import resolver_cliente_villar_do
from utilidades.imagenes import leer_y_normalizar_imagenes
from utilidades.respuestas import respuesta_error


def _asegurar_tablas_dispositivos_promotoras():
    """Tablas propias (no analisis_piel) para no depender de ALTER TABLE.

    analisis_piel es propiedad del rol postgres en produccion y kbeauty_user
    (el rol que usa la API) no puede alterarla ahi. Estas tablas nuevas las
    crea kbeauty_user, asi que son suyas y no tienen ese problema.
    """
    ejecutar(
        """
        CREATE TABLE IF NOT EXISTS promotoras_dispositivos (
            id SERIAL PRIMARY KEY,
            ip_origen VARCHAR(64) UNIQUE NOT NULL,
            etiqueta VARCHAR(50) NOT NULL,
            creado_en TIMESTAMP NOT NULL DEFAULT now()
        )
        """
    )
    ejecutar(
        """
        CREATE TABLE IF NOT EXISTS promotoras_analisis_ip (
            analisis_id UUID PRIMARY KEY,
            ip_origen VARCHAR(64) NOT NULL,
            creado_en TIMESTAMP NOT NULL DEFAULT now()
        )
        """
    )


def _etiqueta_para_ip(ip_origen):
    existente = consultar_uno(
        "SELECT etiqueta FROM promotoras_dispositivos WHERE ip_origen = %s", (ip_origen,)
    )
    if existente:
        return existente["etiqueta"]

    total = consultar_uno("SELECT COUNT(*)::int AS total FROM promotoras_dispositivos")
    etiqueta = f"Promotora {(total or {}).get('total', 0) + 1}"
    creado = ejecutar(
        """
        INSERT INTO promotoras_dispositivos (ip_origen, etiqueta)
        VALUES (%s, %s)
        ON CONFLICT (ip_origen) DO NOTHING
        RETURNING etiqueta
        """,
        (ip_origen, etiqueta),
        retornar=True,
    )
    if creado:
        return creado["etiqueta"]

    # Otra request en paralelo gano la carrera y ya registro esta IP.
    existente = consultar_uno(
        "SELECT etiqueta FROM promotoras_dispositivos WHERE ip_origen = %s", (ip_origen,)
    )
    return (existente or {}).get("etiqueta") or etiqueta


def registrar_ip_promotora(analisis_id, ip_origen):
    ip_origen = (ip_origen or "").strip()
    if not ip_origen:
        return None

    _asegurar_tablas_dispositivos_promotoras()
    etiqueta = _etiqueta_para_ip(ip_origen)
    ejecutar(
        """
        INSERT INTO promotoras_analisis_ip (analisis_id, ip_origen)
        VALUES (%s, %s)
        ON CONFLICT (analisis_id) DO NOTHING
        """,
        (analisis_id, ip_origen),
    )
    return etiqueta


def listar_rutinas_promotoras():
    return obtener_resumen_rutinas()


def analizar_walkin(archivos):
    imagenes = leer_y_normalizar_imagenes(archivos, cantidad_requerida=3)
    return analizar_imagenes_piel(imagenes)


def _construir_rutina_por_nombre(nombre_rutina):
    coincidencia = next(
        (rutina for rutina in listar_rutinas() if rutina.get("nombre") == nombre_rutina),
        None,
    )
    if not coincidencia:
        respuesta_error("Rutina no encontrada", 404)

    rutina = agregar_ubicaciones_a_rutina(deepcopy(coincidencia))
    productos = obtener_productos_de_rutina(rutina)

    return {
        "nombre_rutina": rutina.get("nombre"),
        "tipo_piel": rutina.get("tipo_piel"),
        "condicion": rutina.get("condicion"),
        "criterios": {
            "tipo_piel": rutina.get("tipo_piel"),
            "condicion": rutina.get("condicion"),
            "seleccion": "confirmada_por_promotora",
        },
        "rutina": rutina,
        "productos": productos,
        "odoo_activo": odoo_esta_configurado(),
    }


def guardar_analisis_promotora(datos, ip_origen=None):
    nombre = (datos.get("cliente_nombre") or "").strip()
    telefono = (datos.get("cliente_telefono") or "").strip()
    if not nombre or not telefono:
        respuesta_error("Nombre y telefono del cliente son obligatorios", 422)

    resultado_ia = datos.get("resultado_ia") or {}
    if not resultado_ia:
        respuesta_error("Falta el resultado del analisis de IA", 422)

    resultado_villar = resolver_cliente_villar_do(
        nombre, (datos.get("cliente_apellido") or "").strip(), telefono
    )
    villar_id = (resultado_villar or {}).get("villar_id")
    if not villar_id:
        respuesta_error("No se pudo resolver el cliente en Villar.do", 502)

    asegurar_usuario_local(villar_id, resultado_villar)

    analisis = guardar_analisis(villar_id, resultado_ia)
    ejecutar(
        """
        UPDATE analisis_piel
        SET origen = 'promotora', cliente_nombre = %s, cliente_telefono = %s
        WHERE id = %s
        """,
        (nombre, telefono, analisis["id"]),
    )
    analisis["origen"] = "promotora"
    analisis["cliente_nombre"] = nombre
    analisis["cliente_telefono"] = telefono
    analisis["etiqueta_promotora"] = registrar_ip_promotora(analisis["id"], ip_origen)

    # Si la promotora confirma la rutina (por nombre, de la lista del JSON) se
    # usa esa tal cual. Si no sabe ("No lo se"), la condicion y el tipo de
    # piel salen del mismo analisis de fotos.
    rutina_nombre = (datos.get("rutina_nombre") or "").strip()
    if rutina_nombre:
        recomendacion = _construir_rutina_por_nombre(rutina_nombre)
    else:
        perfil_sintetico = {
            "tipo_piel": resultado_ia.get("tipo_piel_estimado"),
            "condicion_principal": resultado_ia.get("condicion_principal_detectada"),
        }
        recomendacion = preparar_rutina_recomendada(perfil_sintetico, resultado_ia, incluir_odoo=True)

    rutina_guardada = guardar_rutina_recomendada(villar_id, analisis["id"], recomendacion)

    return {
        "analisis": analisis,
        "resultado_ia": resultado_ia,
        "rutina_recomendada": recomendacion,
        "rutina_guardada": rutina_guardada,
        "villar_id": villar_id,
    }


def obtener_historial_promotoras(limite=50, etiqueta_filtro=None):
    _asegurar_tablas_dispositivos_promotoras()
    condiciones = ["ap.origen = 'promotora'"]
    params = []
    if etiqueta_filtro:
        condiciones.append("pd.etiqueta = %s")
        params.append(etiqueta_filtro)
    params.append(limite)
    return consultar_todos(
        f"""
        SELECT ap.id, ap.creado_en, ap.cliente_nombre, ap.cliente_telefono,
               ap.resumen_general, ap.tono_piel, ap.condicion_principal_detectada,
               COALESCE(pd.etiqueta, 'Sin dispositivo registrado') AS etiqueta_promotora
        FROM analisis_piel ap
        LEFT JOIN promotoras_analisis_ip pai ON pai.analisis_id = ap.id
        LEFT JOIN promotoras_dispositivos pd ON pd.ip_origen = pai.ip_origen
        WHERE {" AND ".join(condiciones)}
        ORDER BY ap.creado_en DESC
        LIMIT %s
        """,
        tuple(params),
    )


def obtener_resumen_por_promotora():
    _asegurar_tablas_dispositivos_promotoras()
    return consultar_todos(
        """
        SELECT COALESCE(pd.etiqueta, 'Sin dispositivo registrado') AS etiqueta,
               COUNT(*)::int AS total,
               MAX(ap.creado_en) AS ultimo_analisis
        FROM analisis_piel ap
        LEFT JOIN promotoras_analisis_ip pai ON pai.analisis_id = ap.id
        LEFT JOIN promotoras_dispositivos pd ON pd.ip_origen = pai.ip_origen
        WHERE ap.origen = 'promotora'
        GROUP BY 1
        ORDER BY total DESC, etiqueta
        """
    )


def obtener_detalle_analisis_promotora(analisis_id):
    analisis = consultar_uno(
        "SELECT * FROM analisis_piel WHERE id = %s AND origen = 'promotora'",
        (analisis_id,),
    )
    if not analisis:
        respuesta_error("Analisis no encontrado", 404)

    zonas = consultar_todos(
        "SELECT * FROM analisis_zonas WHERE analisis_id = %s ORDER BY zona",
        (analisis_id,),
    )
    rutina = consultar_uno(
        "SELECT * FROM rutinas_recomendadas WHERE analisis_id = %s ORDER BY creado_en DESC LIMIT 1",
        (analisis_id,),
    )
    productos = []
    if rutina:
        productos = consultar_todos(
            "SELECT * FROM productos_recomendados WHERE rutina_id = %s ORDER BY momento, orden",
            (rutina["id"],),
        )
    return {"analisis": analisis, "zonas": zonas, "rutina": rutina, "productos": productos}
