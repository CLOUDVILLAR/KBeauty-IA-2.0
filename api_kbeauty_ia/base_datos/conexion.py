import psycopg2
from psycopg2.extras import RealDictCursor
from config.configuracion import obtener_configuracion


def obtener_conexion():
    configuracion = obtener_configuracion()
    database_url = configuracion.get("database_url")
    if not database_url:
        raise RuntimeError("DATABASE_URL no esta configurado en .env")
    return psycopg2.connect(database_url, cursor_factory=RealDictCursor)


def probar_conexion():
    conexion = obtener_conexion()
    try:
        with conexion.cursor() as cursor:
            cursor.execute("SELECT 1 AS conectado")
            return cursor.fetchone()
    finally:
        conexion.close()


def consultar_uno(sql, parametros=None):
    conexion = obtener_conexion()
    try:
        with conexion.cursor() as cursor:
            cursor.execute(sql, parametros or ())
            fila = cursor.fetchone()
            return dict(fila) if fila else None
    finally:
        conexion.close()


def consultar_todos(sql, parametros=None):
    conexion = obtener_conexion()
    try:
        with conexion.cursor() as cursor:
            cursor.execute(sql, parametros or ())
            filas = cursor.fetchall()
            return [dict(fila) for fila in filas]
    finally:
        conexion.close()


def ejecutar(sql, parametros=None, retornar=False):
    conexion = obtener_conexion()
    try:
        with conexion.cursor() as cursor:
            cursor.execute(sql, parametros or ())
            resultado = cursor.fetchone() if retornar else None
            conexion.commit()
            return dict(resultado) if resultado else None
    except Exception:
        conexion.rollback()
        raise
    finally:
        conexion.close()


def ejecutar_muchos(sql, lista_parametros):
    conexion = obtener_conexion()
    try:
        with conexion.cursor() as cursor:
            cursor.executemany(sql, lista_parametros)
            conexion.commit()
    except Exception:
        conexion.rollback()
        raise
    finally:
        conexion.close()
