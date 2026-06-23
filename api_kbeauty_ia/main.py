from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config.configuracion import obtener_configuracion
from base_datos.conexion import probar_conexion
from rutas import rutas_usuarios, rutas_perfil, rutas_analisis, rutas_rutinas, rutas_evolucion, rutas_odoo

configuracion = obtener_configuracion()

app = FastAPI(
    title=configuracion["app_nombre"],
    version=configuracion["app_version"],
    description="API KBeauty conectada a Villar.do para identidad centralizada, analisis de piel, rutinas, Odoo y evolucion.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=configuracion["cors_origenes"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(rutas_usuarios.router)
app.include_router(rutas_perfil.router)
app.include_router(rutas_analisis.router)
app.include_router(rutas_rutinas.router)
app.include_router(rutas_evolucion.router)
app.include_router(rutas_odoo.router)


@app.get("/")
def inicio():
    return {
        "correcto": True,
        "mensaje": "KBeauty IA API activa y conectada a Villar.do",
        "documentacion": "/docs",
        "identidad": "Villar.do",
        "villar_do_api_url": configuracion["villar_do_api_url"],
    }


@app.get("/salud")
def salud():
    conexion = probar_conexion()
    return {
        "correcto": True,
        "mensaje": "API funcionando",
        "base_datos_kbeauty": conexion,
        "villar_do_api_url": configuracion["villar_do_api_url"],
        "client_id": configuracion["villar_do_client_id"],
    }
