import base64
import re
import xmlrpc.client
from datetime import date

from config.configuracion import obtener_configuracion


def odoo_esta_configurado():
    configuracion = obtener_configuracion()
    return bool(
        configuracion.get("odoo_activo")
        and configuracion.get("odoo_url")
        and configuracion.get("odoo_db")
        and configuracion.get("odoo_user")
        and configuracion.get("odoo_password")
    )


def conectar_odoo():
    configuracion = obtener_configuracion()
    if not odoo_esta_configurado():
        return None
    comun = xmlrpc.client.ServerProxy(f"{configuracion['odoo_url']}/xmlrpc/2/common")
    uid = comun.authenticate(
        configuracion["odoo_db"],
        configuracion["odoo_user"],
        configuracion["odoo_password"],
        {},
    )
    if not uid:
        return None
    modelos = xmlrpc.client.ServerProxy(f"{configuracion['odoo_url']}/xmlrpc/2/object")
    return {"configuracion": configuracion, "uid": uid, "modelos": modelos}


def ejecutar_odoo(modelo, metodo, argumentos=None, opciones=None):
    conexion = conectar_odoo()
    if not conexion:
        return None
    configuracion = conexion["configuracion"]
    return conexion["modelos"].execute_kw(
        configuracion["odoo_db"],
        conexion["uid"],
        configuracion["odoo_password"],
        modelo,
        metodo,
        argumentos or [],
        opciones or {},
    )


def buscar_producto_por_id(id_odoo):
    try:
        productos = ejecutar_odoo(
            "product.product",
            "read",
            [[int(id_odoo)]],
            {"fields": ["id", "name", "default_code", "barcode", "qty_available", "virtual_available"]},
        )
        if productos:
            return productos[0]
    except Exception as error:
        return {"error": str(error)}
    return None


def obtener_ubicaciones_producto(id_odoo):
    if not odoo_esta_configurado():
        return []
    try:
        campos = ["product_id", "location_id", "quantity", "reserved_quantity", "available_quantity"]
        ubicaciones = ejecutar_odoo(
            "stock.quant",
            "search_read",
            [[("product_id", "=", int(id_odoo)), ("quantity", ">", 0)]],
            {"fields": campos, "limit": 100},
        )
        if ubicaciones is None:
            return []
        return [normalizar_ubicacion(ubicacion) for ubicacion in ubicaciones]
    except Exception as error:
        return [{"error": str(error), "id_odoo": id_odoo}]


def normalizar_ubicacion(ubicacion):
    location_id = ubicacion.get("location_id") or []
    product_id = ubicacion.get("product_id") or []
    cantidad = ubicacion.get("quantity") or 0
    reservado = ubicacion.get("reserved_quantity") or 0
    disponible = ubicacion.get("available_quantity")
    if disponible is None:
        disponible = cantidad - reservado
    return {
        "id_producto": product_id[0] if product_id else None,
        "producto": product_id[1] if len(product_id) > 1 else None,
        "id_ubicacion": location_id[0] if location_id else None,
        "ubicacion": location_id[1] if len(location_id) > 1 else None,
        "cantidad": float(cantidad),
        "reservado": float(reservado),
        "disponible": float(disponible),
    }


def agregar_ubicaciones_a_productos(productos):
    cache = {}
    productos_enriquecidos = []
    for producto in productos:
        copia = dict(producto)
        id_odoo = copia.get("id_odoo")
        if id_odoo not in cache:
            cache[id_odoo] = obtener_ubicaciones_producto(id_odoo)
        copia["ubicaciones_odoo"] = cache[id_odoo]
        copia["odoo_activo"] = odoo_esta_configurado()
        productos_enriquecidos.append(copia)
    return productos_enriquecidos


# =========================================================
# CONEXION SEPARADA: crear/vincular clientes y anclar examenes
# de RX facial. Temporal: mientras se prueba, esta conexion
# apunta a la Odoo de staging aunque la de arriba (productos)
# siga en la Odoo real. Ver ODOO_CLIENTES_* en configuracion.py.
# =========================================================

class InfraOdooClientesError(Exception):
    pass


def _solo_digitos(valor):
    if not valor:
        return None
    digitos = re.sub(r"\D+", "", valor)
    return digitos or None


def odoo_clientes_esta_configurado():
    configuracion = obtener_configuracion()
    return bool(
        configuracion.get("odoo_clientes_activo")
        and configuracion.get("odoo_clientes_url")
        and configuracion.get("odoo_clientes_db")
        and configuracion.get("odoo_clientes_user")
        and configuracion.get("odoo_clientes_password")
    )


def conectar_odoo_clientes():
    configuracion = obtener_configuracion()
    if not odoo_clientes_esta_configurado():
        raise InfraOdooClientesError("La conexion de Odoo para clientes no esta configurada (ODOO_CLIENTES_*)")
    comun = xmlrpc.client.ServerProxy(f"{configuracion['odoo_clientes_url']}/xmlrpc/2/common")
    uid = comun.authenticate(
        configuracion["odoo_clientes_db"],
        configuracion["odoo_clientes_user"],
        configuracion["odoo_clientes_password"],
        {},
    )
    if not uid:
        raise InfraOdooClientesError("Odoo (clientes) rechazo la autenticacion")
    modelos = xmlrpc.client.ServerProxy(f"{configuracion['odoo_clientes_url']}/xmlrpc/2/object")
    return {"configuracion": configuracion, "uid": uid, "modelos": modelos}


def ejecutar_odoo_clientes(modelo, metodo, argumentos=None, opciones=None):
    conexion = conectar_odoo_clientes()
    configuracion = conexion["configuracion"]
    try:
        return conexion["modelos"].execute_kw(
            configuracion["odoo_clientes_db"],
            conexion["uid"],
            configuracion["odoo_clientes_password"],
            modelo,
            metodo,
            argumentos or [],
            opciones or {},
        )
    except xmlrpc.client.Fault as error:
        raise InfraOdooClientesError(f"Odoo Fault ({modelo}.{metodo}): {error.faultString}")


def _buscar_por_termino_telefono_clientes(termino, digitos, limite):
    encontrados = ejecutar_odoo_clientes(
        "res.partner", "search_read",
        [["|", ["phone", "ilike", termino], ["mobile", "ilike", termino]]],
        {"fields": ["id", "name", "phone", "mobile", "villar_id"], "limit": limite},
    ) or []
    for partner in encontrados:
        # Nunca devolver "el primero que aparecio" -- ilike solo acerca
        # candidatos, la confirmacion real es que los digitos completos
        # coincidan exacto.
        if _solo_digitos(partner.get("phone")) == digitos or _solo_digitos(partner.get("mobile")) == digitos:
            return partner
    return None


def buscar_partner_clientes_por_telefono(telefono):
    digitos = _solo_digitos(telefono)
    if not digitos:
        return None

    crudo = (telefono or "").strip()
    # Terminos fuertes (numero completo): poca chance de colision.
    fuertes = [t for t in {crudo, digitos, f"+{digitos}"} if t]
    if len(digitos) >= 10:
        fuertes.append(digitos[-10:])
    for termino in fuertes:
        resultado = _buscar_por_termino_telefono_clientes(termino, digitos, 50)
        if resultado:
            return resultado

    # Terminos debiles (ultimos 4-7 digitos, para telefonos con guiones que
    # cortan la busqueda por numero completo): mucha mas chance de colision
    # (ej. "2020" puede matchear docenas de clientes reales), por eso hace
    # falta un limite bastante mas alto antes de concluir que no hay match.
    debiles = []
    if len(digitos) >= 7:
        debiles.append(digitos[-7:])
    if len(digitos) >= 4:
        debiles.append(digitos[-4:])
    for termino in debiles:
        resultado = _buscar_por_termino_telefono_clientes(termino, digitos, 500)
        if resultado:
            return resultado

    return None


def buscar_partners_clientes_por_nombre(texto, limite=10):
    """Busqueda en vivo (autocompletar) de clientes de Odoo por nombre, para
    el formulario 'sin app' de KBeauty. Devuelve nombre + telefono, nada mas
    -- no se usa para vincular, solo para que el empleado elija y se le
    autocomplete el telefono."""
    texto = (texto or "").strip()
    if len(texto) < 2:
        return []
    encontrados = ejecutar_odoo_clientes(
        "res.partner", "search_read",
        [[["name", "ilike", texto]]],
        {"fields": ["id", "name", "phone", "mobile"], "limit": limite, "order": "name asc"},
    ) or []
    resultados = []
    for partner in encontrados:
        telefono = partner.get("phone") or partner.get("mobile") or ""
        resultados.append({"id": partner["id"], "nombre": partner.get("name") or "", "telefono": telefono})
    return resultados


def crear_partner_clientes(nombre, apellido, telefono):
    nombre_completo = f"{(nombre or '').strip()} {(apellido or '').strip()}".strip() or "Cliente KBeauty"
    vals = {"name": nombre_completo}
    if telefono:
        vals["phone"] = telefono
        vals["mobile"] = telefono
    partner_id = ejecutar_odoo_clientes("res.partner", "create", [vals])
    return {"id": int(partner_id), **vals}


def escribir_villar_id_clientes(partner_id, villar_id):
    ejecutar_odoo_clientes("res.partner", "write", [[int(partner_id)], {"villar_id": str(villar_id)}])


def buscar_o_crear_partner_clientes(nombre, apellido, telefono, villar_id):
    """Busca por telefono; si existe, le escribe el villar_id (sin duplicar).
    Si no existe, crea el contacto ya con su villar_id."""
    partner = buscar_partner_clientes_por_telefono(telefono)
    if not partner:
        partner = crear_partner_clientes(nombre, apellido, telefono)
    escribir_villar_id_clientes(partner["id"], villar_id)
    return partner


def crear_examen_rx_facial(partner_id, pdf_bytes):
    """Crea un registro k_beauty.exam (RX facial) con el PDF adjunto."""
    if not pdf_bytes:
        raise InfraOdooClientesError("PDF vacio, no se puede anclar a RX facial")
    valores = {
        "partner_id": int(partner_id),
        "date": date.today().isoformat(),
        "exam": base64.b64encode(pdf_bytes).decode("ascii"),
    }
    return ejecutar_odoo_clientes("k_beauty.exam", "create", [valores])


def sincronizar_cliente_pdf_rx_facial(nombre, apellido, telefono, villar_id, pdf_bytes):
    """Best-effort: crea/vincula el cliente en Odoo y ancla el PDF en RX facial.

    Nunca lanza excepciones -- no debe bloquear ni afectar la descarga del
    PDF para el empleado si Odoo (clientes) esta caido o mal configurado.
    """
    try:
        if not odoo_clientes_esta_configurado():
            print("[Odoo clientes] conexion no configurada, se omite sync de RX facial")
            return
        partner = buscar_o_crear_partner_clientes(nombre, apellido, telefono, villar_id)
        crear_examen_rx_facial(partner["id"], pdf_bytes)
        print(f"[Odoo clientes] villar_id={villar_id} vinculado a partner id={partner['id']}, examen RX facial creado")
    except Exception as error:
        print(f"[Odoo clientes] error sincronizando villar_id={villar_id}: {error}")
