import xmlrpc.client
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
