import base64
import io
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError

from utilidades.respuestas import respuesta_error

try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except Exception:
    # Si pillow-heif no esta instalado, la app igual soporta los formatos de Pillow.
    pass


EXTENSIONES_IMAGEN = {
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff",
    ".heic", ".heif", ".avif", ".jfif", ".pjpeg", ".pjp",
}


FORMATOS_PERMITIDOS_TEXTO = "JPG, JPEG, PNG, WEBP, GIF, BMP, TIFF, HEIC/HEIF y otros formatos de imagen que pueda leer Pillow"


def normalizar_content_type(content_type):
    if not content_type:
        return "application/octet-stream"
    return content_type.split(";")[0].strip().lower()


def obtener_extension_archivo(archivo):
    nombre = getattr(archivo, "filename", "") or ""
    return Path(nombre).suffix.lower()


def es_content_type_de_imagen(content_type):
    content_type = normalizar_content_type(content_type)
    return content_type.startswith("image/")


def es_extension_de_imagen(extension):
    return extension.lower() in EXTENSIONES_IMAGEN


def convertir_a_jpeg(bytes_imagen, nombre_campo="imagen"):
    try:
        imagen = Image.open(io.BytesIO(bytes_imagen))
        formato_original = imagen.format or "desconocido"
        imagen = ImageOps.exif_transpose(imagen)

        if imagen.mode in ("RGBA", "LA") or (imagen.mode == "P" and "transparency" in imagen.info):
            fondo = Image.new("RGB", imagen.size, (255, 255, 255))
            if imagen.mode != "RGBA":
                imagen = imagen.convert("RGBA")
            fondo.paste(imagen, mask=imagen.getchannel("A"))
            imagen = fondo
        else:
            imagen = imagen.convert("RGB")

        salida = io.BytesIO()
        imagen.save(salida, format="JPEG", quality=92, optimize=True)
        return salida.getvalue(), formato_original

    except UnidentifiedImageError:
        respuesta_error(
            f"El archivo {nombre_campo} no se pudo leer como imagen valida. Formatos aceptados: {FORMATOS_PERMITIDOS_TEXTO}.",
            422,
        )
    except Exception as error:
        respuesta_error(
            f"No se pudo procesar la imagen {nombre_campo}: {error}",
            422,
        )


def leer_y_normalizar_imagen(archivo, nombre_campo="imagen"):
    content_type_original = normalizar_content_type(getattr(archivo, "content_type", ""))
    extension = obtener_extension_archivo(archivo)

    # En Windows, emuladores o file_picker, muchos archivos llegan como application/octet-stream.
    # Por eso NO confiamos solo en content_type. Validamos por extension y, sobre todo, intentando abrir la imagen.
    if not es_content_type_de_imagen(content_type_original) and not es_extension_de_imagen(extension):
        # Aun asi intentamos leerla, porque algunos sistemas no mandan extension ni MIME correcto.
        pass

    try:
        bytes_originales = archivo.file.read()
    except Exception:
        respuesta_error(f"No se pudo leer el archivo {nombre_campo}", 422)

    if not bytes_originales:
        respuesta_error(f"La imagen {nombre_campo} esta vacia", 422)

    bytes_jpeg, formato_original = convertir_a_jpeg(bytes_originales, nombre_campo)

    return {
        "nombre": nombre_campo,
        "bytes": bytes_jpeg,
        "content_type": "image/jpeg",
        "content_type_original": content_type_original,
        "formato_original": formato_original,
        "nombre_archivo": getattr(archivo, "filename", ""),
    }


def leer_y_normalizar_imagenes(archivos, cantidad_requerida=3):
    if not archivos or len(archivos) != cantidad_requerida:
        respuesta_error(
            f"Debes enviar exactamente {cantidad_requerida} fotos: frente, lado izquierdo y lado derecho.",
            422,
            {"cantidad_recibida": len(archivos or [])},
        )

    nombres = ["frente", "lado_izquierdo", "lado_derecho"]
    imagenes = []

    for indice, archivo in enumerate(archivos):
        imagenes.append(leer_y_normalizar_imagen(archivo, nombres[indice]))

    return imagenes


def validar_imagen(archivo):
    # Compatibilidad con codigo viejo. Lee y valida una imagen sin guardar nada.
    leer_y_normalizar_imagen(archivo)
    return True


def validar_imagenes(archivos, cantidad_requerida=3):
    # Compatibilidad con codigo viejo. Valida intentando abrir cada imagen.
    leer_y_normalizar_imagenes(archivos, cantidad_requerida)
    return True


def convertir_imagen_a_base64(bytes_imagen):
    return base64.b64encode(bytes_imagen).decode("utf-8")


def crear_data_url_imagen(bytes_imagen, content_type):
    # Las imagenes se normalizan a JPEG antes de llegar aqui.
    imagen_base64 = convertir_imagen_a_base64(bytes_imagen)
    return f"data:image/jpeg;base64,{imagen_base64}"
