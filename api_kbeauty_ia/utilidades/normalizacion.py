import unicodedata


def quitar_acentos(texto):
    if texto is None:
        return ""
    texto_normalizado = unicodedata.normalize("NFKD", str(texto))
    return "".join(letra for letra in texto_normalizado if not unicodedata.combining(letra))


def normalizar_texto(texto):
    return quitar_acentos(texto).strip().lower()


def normalizar_tipo_piel(tipo_piel):
    valor = normalizar_texto(tipo_piel)
    mapa = {
        "seca": "seca",
        "grasa": "grasa",
        "mixta": "mixta",
        "normal": "normal",
        "sensible": "sensible",
    }
    return mapa.get(valor, valor)


def normalizar_condicion(condicion):
    valor = normalizar_texto(condicion)
    mapa = {
        "ninguna": "none",
        "sin manchas": "none",
        "sin condicion": "none",
        "none": "none",
        "acne": "acne",
        "acneica": "acne",
        "tendencia acneica": "acne",
        "acneica": "acne",
        "melasma": "melasma",
        "manchas": "manchas",
        "mancha": "manchas",
        "arrugas": "arrugas",
        "anti age": "anti-age",
        "antiage": "anti-age",
        "opaca": "opaca",
    }
    return mapa.get(valor, valor)


def convertir_a_numero(valor, defecto=0):
    try:
        return float(valor)
    except (TypeError, ValueError):
        return defecto
