# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

KBeauty IA: a skin-analysis app with two codebases in one repo, both written entirely in **Spanish** (identifiers, routes, messages, commits). Follow that convention.

- **Flutter app** (root, `lib/`) — mobile client.
- **FastAPI backend** (`api_kbeauty_ia/`) — Python API with its own venv, PostgreSQL DB (`kbeauty_ia_v2`), and OpenAI integration.

Identity is **delegated to Villar.do** (external SSO service). KBeauty stores no emails/passwords — only app data keyed by `villar_id`. Every protected endpoint validates the bearer token against Villar.do's API.

## Commands

### Flutter (from repo root)

```powershell
flutter pub get
flutter analyze
flutter test                          # only default widget_test.dart exists
flutter run --dart-define=URL_API=http://TU_IP_PC:8000 --dart-define=URL_VILLAR_DO=http://TU_IP_PC:8100
# Android emulator: use http://10.0.2.2:8000 / :8100
```

Without `--dart-define`, [config.dart](lib/config/config.dart) defaults to the production API (`http://3.143.67.15:8000`) and `https://apps.villar.do/`.

### Backend (from `api_kbeauty_ia/`)

```powershell
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000   # or .\start.bat
```

Config comes from `api_kbeauty_ia/.env` (not committed; see `api_kbeauty_ia/README.md` for variables). For development set `OPENAI_MODO_DEMO=true` to skip real OpenAI calls. Swagger UI at `/docs`, health check at `/salud`.

There are no backend tests or linter configured.

## Architecture

```
Flutter app ──> API KBeauty (:8000) ──valida token──> API Villar.do (:8100) ──> DB Villar.do
                     └──> DB PostgreSQL kbeauty_ia_v2 (datos de piel, analisis, rutinas)
```

### Backend (`api_kbeauty_ia/`)

Layered: `rutas/` (APIRouter per domain) → `servicios/` (business logic) → `base_datos/conexion.py` (raw psycopg2 helpers: `consultar_uno`, `consultar_todos`, `ejecutar` — **no ORM**, SQL strings with `%s` params, RealDictCursor).

- **Response envelope**: every endpoint returns `respuesta_correcta(mensaje, datos)` → `{"correcto": true, "mensaje": ..., "datos": {...}}`. Errors go through `respuesta_error(mensaje, codigo, detalles)` in [utilidades/respuestas.py](api_kbeauty_ia/utilidades/respuestas.py), which **raises** an HTTPException (it does not return).
- **Auth**: protected routes use `Depends(obtener_usuario_actual)` from [dependencias/autenticacion.py](api_kbeauty_ia/dependencias/autenticacion.py). It validates the token against Villar.do, then `asegurar_usuario_local` auto-creates/fetches the local user row by `villar_id`. Server-to-server calls to Villar.do live in [servicio_villar_do.py](api_kbeauty_ia/servicios/servicio_villar_do.py) and send the `VILLAR_DO_APP_KEY`.
- **Routers**: `/usuarios` (proxy registro/login/refresh a Villar.do), `/perfil` (formulario de piel), `/analisis` (3 fotos multipart: `frente`, `lado_izquierdo`, `lado_derecho` → OpenAI), `/rutinas` (recomendaciones desde `datos/Completa_rutinas.json`), `/evolucion`, `/chat`, `/odoo` (opcional, gated por `ODOO_ACTIVO`), `/analisis-externos`.
- **KBEAUTY-DATA** ([rutas_kbeauty_data.py](api_kbeauty_ia/rutas/rutas_kbeauty_data.py)): a large server-rendered HTML admin dashboard (statistics, clients, roles, presencial PDFs) with its own cookie-based SSO login (`kbeauty_data_token`) and role checks (`exigir_admin` / `exigir_empleado`). Recent feature work (dashboard, filters, statistics) happens here.
- Uploaded analysis images/PDFs are stored on disk under `almacenamiento/`.

### Flutter (`lib/`)

No state-management package — plain top-level functions and `StatefulWidget`s.

- [config.dart](lib/config/config.dart) centralizes all API route constants; they must stay in sync with backend routers.
- [servicio_api.dart](lib/servicios/servicio_api.dart) is the single HTTP layer: builds headers (Villar.do app-key headers + bearer), stores tokens in `flutter_secure_storage`, auto-refreshes on 401 (deduplicated via `_refreshEnCurso`), and throws `SesionExpiradaException` when the session dies. Use `enviarGet`/`enviarPost`/`enviarTresImagenes` — don't call `http` directly from screens.
- Other `servicios/*.dart` wrap specific endpoints; `pantallas/` are screens (`pantalla_*`), `widgets/` shared UI (`tarjeta_*`, `boton_principal`, etc.).
- SSO uses the deep link `kbeauty://auth/callback` (via `app_links`); `servicio_api.dart` contains careful callback-dedup/lockout logic (`bloquearCallbacksTemporalmente`, `borrarSesionLocalYVerificar`) to prevent Android from reprocessing the last SSO link after logout — be cautious when touching session/logout code.

## Producción / Despliegue

La API corre en EC2 (`3.143.67.15`, Ubuntu, usuario `ubuntu`; llave SSH `VILLAR-DO-KEY.pem` en la raíz local, ignorada por git). El repo está clonado en `/opt/KBeauty-IA-2.0` y el servicio systemd `kbeauty.service` ejecuta uvicorn desde el venv del servidor en el puerto 8000 (expuesto directo, sin nginx). PostgreSQL es local en el mismo servidor (DB `kbeauty_ia_v2`); el `.env` de producción vive en `/opt/KBeauty-IA-2.0/api_kbeauty_ia/.env`.

Flujo de deploy:

```powershell
git push                                                            # a main
ssh -i VILLAR-DO-KEY.pem ubuntu@3.143.67.15 "cd /opt/KBeauty-IA-2.0 && git pull && sudo systemctl restart kbeauty"
ssh -i VILLAR-DO-KEY.pem ubuntu@3.143.67.15 "curl -s localhost:8000/salud"
```

El reinicio solo es necesario si cambió código Python o datos que se cargan en memoria (p. ej. `datos/Completa_rutinas.json`). En el servidor, `almacenamiento/` contiene PDFs/imágenes de usuarios reales que aparecen como untracked — no tocarlos.

## Gotchas

- `api_kbeauty_ia/README.md` references `sql/crear_tablas.sql`, but that file is not in the repo; the DB schema must be inferred from the SQL in `servicios/`.
- The repo root contains build artifacts (`build/`, `KBEAUTY-IA.apk`) and the backend venv (`api_kbeauty_ia/venv/`) — exclude them from searches.
