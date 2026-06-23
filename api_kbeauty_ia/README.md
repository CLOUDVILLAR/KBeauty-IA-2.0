# KBeauty IA API conectada a Villar.do

Esta version de KBeauty ya no guarda usuarios con correo ni contrasena. La identidad vive en Villar.do y KBeauty guarda solo datos propios de la app usando `villar_id`.

## Arquitectura

```txt
Flutter KBeauty
    ↓
API KBeauty
    ↓ valida token
API Villar.do
    ↓
DB Villar.do

API KBeauty
    ↓ datos de piel, analisis, rutinas
DB kbeauty_ia_v2
```

## Lo que cambia

- `POST /usuarios/registro` crea el usuario en Villar.do y luego crea el perfil local en KBeauty con `villar_id`.
- `POST /usuarios/login` autentica contra Villar.do.
- Las rutas protegidas usan `Authorization: Bearer <access_token_de_villar_do>`.
- KBeauty valida el token llamando a `POST /api/auth/validar-token` de Villar.do.
- La DB de KBeauty ya no tiene `correo`, `nombre`, `contrasena_hash` ni datos basicos del usuario.

## Variables de entorno

Copia `.env.example` como `.env` y ajusta:

```env
DATABASE_URL=postgresql://kbeauty_user:kbeauty123@localhost:5432/kbeauty_ia_v2
VILLAR_DO_API_URL=http://localhost:8100
VILLAR_DO_CLIENT_ID=kbeauty_ia
OPENAI_API_KEY=...
OPENAI_MODO_DEMO=true
```

Para desarrollo puedes dejar `OPENAI_MODO_DEMO=true` hasta resolver billing/tokens de OpenAI.

## Instalacion

```powershell
cd api_kbeauty_ia
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

## Base de datos

Ejecuta conectado a `kbeauty_ia_v2`:

```sql
-- archivo incluido
sql/crear_tablas.sql
```

Este script recrea tablas de KBeauty adaptadas a Villar.do.

## Ejecutar

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

O usa:

```powershell
.\start.bat
```

## Endpoints importantes

### Registro proxy hacia Villar.do

```http
POST /usuarios/registro
Content-Type: application/json

{
  "nombre": "Ana",
  "apellido": "Perez",
  "correo": "ana@example.com",
  "contrasena": "123456",
  "telefono": "8090000000",
  "pais": "Republica Dominicana",
  "ciudad": "Santo Domingo"
}
```

Respuesta relevante:

```json
{
  "datos": {
    "villar_id": "...",
    "token": "access_token_de_villar_do",
    "refresh_token": "...",
    "usuario": {
      "villar_id": "...",
      "formulario_completado": false
    },
    "usuario_villar": {
      "correo": "ana@example.com"
    }
  }
}
```

### Login proxy hacia Villar.do

```http
POST /usuarios/login
Content-Type: application/json

{
  "correo": "ana@example.com",
  "contrasena": "123456"
}
```

### Usar token en KBeauty

```http
Authorization: Bearer <token_de_villar_do>
```

### Perfil de piel

```http
POST /perfil/formulario
Authorization: Bearer <token>
Content-Type: application/json

{
  "tipo_piel": "seca",
  "condicion_principal": "melasma",
  "rango_edad": "25-34",
  "sensibilidad": "media",
  "usa_protector_solar": true
}
```

### Analisis

```http
POST /analisis/nuevo
Authorization: Bearer <token>
multipart/form-data:
  frente
  lado_izquierdo
  lado_derecho
```

## Nota

El analisis de piel es cosmetico y orientativo. No reemplaza una evaluacion medica o dermatologica.


## Villar.do Developer App Key

Esta version envia la App Key de Villar.do Developer en cada llamada servidor-a-servidor hacia Villar.do.
Agrega esta variable en tu `.env` local de KBeauty:

```env
VILLAR_DO_APP_KEY=villar_sk_dev_TU_KEY_GENERADA_EN_VILLAR_DO_DEVELOPER
```

No se incluye archivo `.env` en este ZIP.
