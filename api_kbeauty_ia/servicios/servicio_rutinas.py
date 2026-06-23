import json
from copy import deepcopy
from pathlib import Path
from config.configuracion import obtener_configuracion
from utilidades.normalizacion import normalizar_tipo_piel, normalizar_condicion, normalizar_texto
from servicios.servicio_odoo import obtener_ubicaciones_producto, odoo_esta_configurado

_cache_rutinas = None


def cargar_rutinas(forzar=False):
    global _cache_rutinas
    if _cache_rutinas is not None and not forzar:
        return _cache_rutinas
    configuracion = obtener_configuracion()
    ruta = Path(configuracion["ruta_rutinas"])
    if not ruta.exists():
        ruta = Path(__file__).resolve().parents[1] / configuracion["ruta_rutinas"]
    with ruta.open("r", encoding="utf-8") as archivo:
        _cache_rutinas = json.load(archivo)
    return _cache_rutinas


def listar_rutinas():
    datos = cargar_rutinas()
    return datos.get("rutinas_por_piel", [])


def obtener_resumen_rutinas():
    return [
        {
            "nombre": rutina.get("nombre"),
            "tipo_piel": rutina.get("tipo_piel"),
            "condicion": rutina.get("condicion"),
        }
        for rutina in listar_rutinas()
    ]


def buscar_rutina_por_tipo_y_condicion(tipo_piel, condicion):
    tipo = normalizar_tipo_piel(tipo_piel)
    condicion_normalizada = normalizar_condicion(condicion)
    rutinas = listar_rutinas()

    coincidencias_exactas = [
        rutina for rutina in rutinas
        if normalizar_tipo_piel(rutina.get("tipo_piel")) == tipo
        and normalizar_condicion(rutina.get("condicion")) == condicion_normalizada
    ]
    if coincidencias_exactas:
        return deepcopy(coincidencias_exactas[0])

    coincidencias_sin_condicion = [
        rutina for rutina in rutinas
        if normalizar_tipo_piel(rutina.get("tipo_piel")) == tipo
        and normalizar_condicion(rutina.get("condicion")) == "none"
    ]
    if coincidencias_sin_condicion:
        return deepcopy(coincidencias_sin_condicion[0])

    coincidencias_tipo = [
        rutina for rutina in rutinas
        if normalizar_tipo_piel(rutina.get("tipo_piel")) == tipo
    ]
    if coincidencias_tipo:
        return deepcopy(coincidencias_tipo[0])

    return deepcopy(rutinas[0]) if rutinas else None


def obtener_productos_de_rutina(rutina):
    productos = []
    if not rutina:
        return productos
    bloques = rutina.get("rutina") or {}
    for momento, pasos in bloques.items():
        for indice, producto in enumerate(pasos or []):
            copia = dict(producto)
            copia["momento"] = momento
            copia["orden"] = indice + 1
            productos.append(copia)
    return productos


def agregar_ubicaciones_a_rutina(rutina):
    if not rutina:
        return rutina
    cache_ubicaciones = {}
    bloques = rutina.get("rutina") or {}
    for momento, pasos in bloques.items():
        for producto in pasos or []:
            id_odoo = producto.get("id_odoo")
            if id_odoo not in cache_ubicaciones:
                cache_ubicaciones[id_odoo] = obtener_ubicaciones_producto(id_odoo)
            producto["ubicaciones_odoo"] = cache_ubicaciones[id_odoo]
            producto["odoo_activo"] = odoo_esta_configurado()
    return rutina


def elegir_condicion_para_rutina(perfil, resultado_ia):
    condicion_perfil = normalizar_condicion((perfil or {}).get("condicion_principal"))
    condicion_ia = normalizar_condicion((resultado_ia or {}).get("condicion_principal_detectada"))
    if condicion_perfil and condicion_perfil != "none":
        return condicion_perfil
    if condicion_ia:
        return condicion_ia
    return "none"


def preparar_rutina_recomendada(perfil, resultado_ia=None, incluir_odoo=True):
    tipo_piel = normalizar_tipo_piel((perfil or {}).get("tipo_piel"))
    condicion = elegir_condicion_para_rutina(perfil, resultado_ia or {})
    rutina = buscar_rutina_por_tipo_y_condicion(tipo_piel, condicion)
    if incluir_odoo:
        rutina = agregar_ubicaciones_a_rutina(rutina)
    productos = obtener_productos_de_rutina(rutina)

    nombre_rutina = "Rutina recomendada"
    tipo_piel_rutina = tipo_piel or "N/D"
    condicion_rutina = condicion or "N/D"
    if rutina:
        nombre_rutina = rutina.get("nombre") or nombre_rutina
        tipo_piel_rutina = rutina.get("tipo_piel") or tipo_piel_rutina
        condicion_rutina = rutina.get("condicion") or condicion_rutina

    return {
        "nombre_rutina": nombre_rutina,
        "tipo_piel": tipo_piel_rutina,
        "condicion": condicion_rutina,
        "criterios": {"tipo_piel": tipo_piel, "condicion": condicion},
        "rutina": rutina,
        "productos": productos,
        "odoo_activo": odoo_esta_configurado(),
    }


def buscar_texto_en_rutinas(texto):
    texto_normalizado = normalizar_texto(texto)
    resultados = []
    for rutina in listar_rutinas():
        nombre = normalizar_texto(rutina.get("nombre"))
        tipo = normalizar_texto(rutina.get("tipo_piel"))
        condicion = normalizar_texto(rutina.get("condicion"))
        if texto_normalizado in nombre or texto_normalizado in tipo or texto_normalizado in condicion:
            resultados.append(rutina)
    return resultados
