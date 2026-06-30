from html import escape
from urllib.parse import quote

from fastapi import APIRouter, Request, Form, File, UploadFile, Query
from fastapi.responses import HTMLResponse, RedirectResponse, FileResponse

from servicios.servicio_kbeauty_data import (
    ROLES_ADMIN,
    ROLES_EMPLEADO,
    asignar_rol_a_villar_id,
    buscar_clientes,
    construir_url_login_sso,
    codigos_roles,
    exigir_admin,
    exigir_empleado,
    extraer_token_callback,
    guardar_pdf_presencial,
    intercambiar_codigo_sso,
    listar_roles,
    listar_usuarios_kbeauty,
    quitar_rol_a_villar_id,
    eliminar_usuario_kbeauty,
    obtener_pdf_presencial,
    obtener_cliente_kdata,
    usuario_desde_token_web,
    usuario_tiene_rol,
)
from utilidades.respuestas import respuesta_correcta, respuesta_error

router = APIRouter(tags=["KBEAUTY-DATA"])
COOKIE = "kbeauty_data_token"


def _redirect_login_limpiando_sesion(destino: str):
    respuesta = RedirectResponse(f"/kbeauty-data/login?next={quote(destino)}", status_code=302)
    respuesta.delete_cookie(COOKIE)
    return respuesta


def _html_base(titulo, contenido, usuario=None, mostrar_nav=True):
    nombre = ""
    if usuario:
        datos = usuario.get("datos_villar") or {}
        nombre = datos.get("nombre") or datos.get("correo") or str(usuario.get("villar_id"))
    sesion = f"<span>Sesion: <b>{escape(nombre)}</b></span> <a href='/kbeauty-data/logout'>Salir</a>" if usuario else ""
    nav_html = f"""
      <nav>
        <a href="/kbeauty-data/admin">Admin</a>
        <a href="/kbeauty-data/empleados">Empleados</a>
        <a href="/docs">Docs API</a>
        <div class="right">{sesion}</div>
      </nav>
    """ if mostrar_nav else ""
    return f"""
    <!doctype html>
    <html lang="es">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>{escape(titulo)}</title>
      <style>
        body {{ margin:0; font-family: Arial, sans-serif; background:#f3f6fb; color:#06142e; }}
        nav {{ padding:14px 24px; background:#fff; box-shadow:0 1px 8px rgba(255,42,65,.08); display:flex; gap:18px; align-items:center; }}
        nav a {{ color:#06142e; font-weight:700; }}
        .right {{ margin-left:auto; display:flex; gap:12px; align-items:center; font-size:14px; }}
        .wrap {{ max-width:1180px; margin:28px auto; padding:0 18px; }}
        .hero,.card {{ background:white; border-radius:22px; padding:26px; box-shadow:0 12px 35px rgba(20,36,66,.08); margin-bottom:24px; }}
        h1 {{ margin:0 0 10px; font-size:32px; }} h2 {{ margin-top:0; }}
        input,textarea,select {{ width:100%; box-sizing:border-box; padding:12px; border:1px solid #ccd6e3; border-radius:12px; font-size:15px; margin-top:6px; }}
        label {{ font-weight:700; display:block; margin-top:12px; }}
        button,.btn {{ display:inline-block; padding:12px 16px; border:0; border-radius:14px; background:linear-gradient(135deg,#f51d37,#ff6475); color:#fff; font-weight:800; cursor:pointer; text-decoration:none; margin-top:14px; box-shadow:0 12px 24px rgba(245,29,55,.22); }}
        table {{ width:100%; border-collapse:collapse; background:#fff; }} th,td {{ padding:12px; border-bottom:1px solid #e5ebf2; text-align:left; vertical-align:top; }}
        th {{ font-size:13px; color:#3a4b63; }} code {{ background:#eef3fa; padding:4px 7px; border-radius:8px; font-size:12px; }}
        .grid {{ display:grid; grid-template-columns:1fr 1fr; gap:20px; }} .ok {{ background:#e7fff2; color:#065f46; padding:12px; border-radius:14px; }}
        .warn {{ background:#fff7df; color:#755000; padding:12px; border-radius:14px; }} .small {{ font-size:13px; color:#53657d; }}
        .pill {{ display:inline-block; padding:4px 8px; border-radius:999px; background:#eef3fa; margin:2px; font-size:12px; }}
        @media(max-width:800px) {{ .grid {{ grid-template-columns:1fr; }} }}
      </style>
    </head>
    <body>
      {nav_html}
      <main class="wrap">{contenido}</main>
    </body>
    </html>
    """


def _usuario_web_o_redirect(request: Request, destino: str):
    token = request.cookies.get(COOKIE)
    usuario = usuario_desde_token_web(token) if token else None
    if not usuario:
        return None, _redirect_login_limpiando_sesion(destino)
    return usuario, None


def _usuario_web_o_bearer(request: Request, destino: str = "/kbeauty-data/empleados"):
    """Acepta sesion web KBEAUTY-DATA o token movil Authorization: Bearer.

    Las vistas web usan cookie, pero Flutter abre el PDF con token.
    Por eso estas rutas publicas de analisis presencial deben soportar ambos caminos.
    """
    token_cookie = request.cookies.get(COOKIE)
    usuario = usuario_desde_token_web(token_cookie) if token_cookie else None
    if usuario:
        return usuario, None

    autorizacion = request.headers.get("authorization") or request.headers.get("Authorization") or ""
    partes = autorizacion.split(None, 1)
    if len(partes) == 2 and partes[0].lower() == "bearer":
        usuario = usuario_desde_token_web(partes[1].strip())
        if usuario:
            return usuario, None

    return None, _redirect_login_limpiando_sesion(destino)


@router.get("/kbeauty-data/login")
def login_kbeauty_data(next: str = Query("/kbeauty-data/empleados")):
    return RedirectResponse(construir_url_login_sso(next), status_code=302)


@router.get("/kbeauty-data/logout")
def logout_kbeauty_data():
    respuesta = RedirectResponse("/kbeauty-data/login", status_code=302)
    respuesta.delete_cookie(COOKIE)
    return respuesta


@router.get("/kbeauty-data/sso/callback")
def callback_sso(request: Request):
    token = extraer_token_callback(request.query_params)
    if not token:
        token = intercambiar_codigo_sso(request.query_params.get("code"))
    if not token:
        return HTMLResponse(_html_base("SSO error", "<div class='card'><h1>No se recibio token de Villar.do</h1><p>Revisa el redirect_uri y la configuracion de la App Key.</p></div>"), status_code=400)
    usuario = usuario_desde_token_web(token)
    if not usuario:
        return _redirect_login_limpiando_sesion("/kbeauty-data/empleados")
    destino = request.query_params.get("estado") or request.query_params.get("state") or "/kbeauty-data/empleados"
    if not destino.startswith("/kbeauty-data/"):
        destino = "/kbeauty-data/empleados"
    respuesta = RedirectResponse(destino, status_code=302)
    respuesta.set_cookie(COOKIE, token, httponly=True, samesite="lax", secure=False, max_age=60 * 60 * 24 * 7)
    return respuesta


@router.get("/kbeauty-data/admin", response_class=HTMLResponse)
def vista_admin(request: Request, q: str = ""):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    if not usuario_tiene_rol(usuario, ROLES_ADMIN):
        return HTMLResponse(
            _html_base(
                "Sin permiso",
                "<div class='admin-shell'><div class='empty-card'><h1>Acceso denegado</h1><p>Tu usuario no tiene permiso de administrador para KBEAUTY-DATA.</p><a class='btn ghost' href='/kbeauty-data/empleados'>Ir a empleados</a></div></div>",
                usuario,
                mostrar_nav=False,
            ),
            status_code=403,
        )

    roles = listar_roles()
    usuarios = listar_usuarios_kbeauty(q, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar"))
    opciones_roles = "".join([
        f"<option value='{escape(r['codigo'])}'>{escape(r['codigo'])}</option>"
        for r in roles
    ])

    filas = "".join([
        f"""
        <article class='user-card'>
          <div class='user-main'>
            <div class='avatar'>{escape((u.get('villar_nombre') or 'K')[:1].upper())}</div>
            <div class='user-info'>
              <h3>{escape(u.get('villar_nombre') or 'Sin nombre')}</h3>
              <p>{escape(u.get('villar_correo') or 'Correo no disponible')}</p>
              <small>{escape(u.get('villar_telefono') or '')}</small>
              {f"<small class='warn-text'>Villar.do: {escape(u.get('villar_error'))}</small>" if u.get('villar_error') else ""}
              <div class='ids'>
                <span>ID KBeauty: <code>{escape(str(u.get('id')))}</code></span>
                <span>Villar ID: <code>{escape(str(u.get('villar_id')))}</code></span>
              </div>
            </div>
          </div>

          <div class='profile-mini'>
            <span>Tipo de piel</span><b>{escape(u.get('tipo_piel') or 'Sin perfil')}</b>
            <span>Condición</span><b>{escape(u.get('condicion_principal') or 'No definida')}</b>
          </div>

          <div class='roles-box'>
            <div class='roles-list'>
              {''.join([f"<span class='role-chip'>{escape(r.get('codigo',''))}<form method='post' action='/kbeauty-data/admin/roles/quitar' onsubmit=\"return confirm('Quitar este rol?')\"><input type='hidden' name='villar_id' value='{escape(str(u.get('villar_id')))}'><input type='hidden' name='codigo_rol' value='{escape(r.get('codigo',''))}'><button type='submit' class='chip-x'>×</button></form></span>" for r in u.get('roles', [])]) or "<span class='muted'>Sin roles asignados</span>"}
            </div>
            <form class='inline-form' method='post' action='/kbeauty-data/admin/roles/asignar'>
              <input type='hidden' name='villar_id' value='{escape(str(u.get('villar_id')))}'>
              <select name='codigo_rol'>{opciones_roles}</select>
              <button type='submit'>Añadir rol</button>
            </form>
          </div>

          <form class='delete-form' method='post' action='/kbeauty-data/admin/usuarios/eliminar' onsubmit="return confirm('Esto eliminará este usuario de KBeauty y sus datos relacionados. ¿Continuar?')">
            <input type='hidden' name='villar_id' value='{escape(str(u.get('villar_id')))}'>
            <button type='submit'>Eliminar usuario</button>
          </form>
        </article>
        """ for u in usuarios
    ]) or "<div class='empty-card'><h2>No hay usuarios</h2><p>Prueba con otro correo, nombre o Villar ID.</p></div>"

    contenido = f"""
    <style>
      body {{
        margin:0;
        min-height:100vh;
        font-family: Arial, sans-serif;
        background:
          radial-gradient(circle at 12% 8%, rgba(255,255,255,.65), transparent 32%),
          linear-gradient(160deg,#ffe5ea 0%,#ffd3dc 45%,#ffb8c5 100%);
        color:#42131b;
      }}
      .wrap {{ max-width:1200px; margin:0 auto; padding:0; }}
      .admin-shell {{ padding:28px; }}
      .topbar {{ display:flex; justify-content:space-between; align-items:center; gap:16px; margin-bottom:24px; }}
      .brand {{ display:flex; align-items:center; gap:14px; }}
      .logo-dot {{ width:46px; height:46px; border-radius:18px; background:linear-gradient(135deg,#f51d37,#ff6d7d); box-shadow:0 14px 30px rgba(245,29,55,.25); }}
      .brand h1 {{ margin:0; font-size:30px; letter-spacing:-.6px; }}
      .brand p {{ margin:4px 0 0; color:#8f4350; }}
      .actions {{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }}
      .btn, button {{ border:0; border-radius:18px; padding:12px 16px; font-weight:800; cursor:pointer; text-decoration:none; }}
      .btn.primary, button {{ background:linear-gradient(135deg,#f51d37,#ff6578); color:white; box-shadow:0 14px 28px rgba(245,29,55,.22); }}
      .btn.ghost {{ background:rgba(255,255,255,.72); color:#f51d37; border:1px solid rgba(245,29,55,.18); }}
      .search-card {{ background:rgba(255,255,255,.78); backdrop-filter:blur(12px); border:1px solid rgba(255,255,255,.75); border-radius:30px; padding:20px; box-shadow:0 18px 45px rgba(121,30,46,.12); margin-bottom:18px; }}
      .search-card label {{ display:block; font-weight:900; margin-bottom:8px; }}
      .search-row {{ display:grid; grid-template-columns:1fr auto; gap:12px; }}
      input, select {{ width:100%; box-sizing:border-box; border:1px solid rgba(245,29,55,.16); border-radius:18px; padding:13px 14px; font-size:15px; outline:none; background:#fff; }}
      input:focus, select:focus {{ border-color:#f51d37; box-shadow:0 0 0 4px rgba(245,29,55,.10); }}
      .summary {{ display:flex; gap:10px; flex-wrap:wrap; margin:0 0 18px; }}
      .summary span {{ background:rgba(255,255,255,.68); border-radius:999px; padding:9px 12px; color:#7c2c39; font-weight:800; }}
      .users-grid {{ display:grid; grid-template-columns:1fr; gap:16px; }}
      .user-card {{ background:rgba(255,255,255,.84); border:1px solid rgba(255,255,255,.8); border-radius:28px; padding:18px; box-shadow:0 16px 42px rgba(93,20,35,.12); display:grid; grid-template-columns:1.35fr .55fr .9fr auto; gap:18px; align-items:center; }}
      .user-main {{ display:flex; gap:14px; align-items:flex-start; min-width:0; }}
      .avatar {{ flex:0 0 auto; width:50px; height:50px; border-radius:19px; display:grid; place-items:center; background:linear-gradient(135deg,#f51d37,#ff7b8b); color:white; font-weight:900; font-size:20px; }}
      .user-info h3 {{ margin:0; font-size:18px; }}
      .user-info p {{ margin:4px 0; color:#7c2c39; font-weight:700; }}
      .user-info small {{ display:block; color:#9a5a64; }}
      .warn-text {{ color:#b45309!important; }}
      .ids {{ margin-top:10px; display:flex; flex-direction:column; gap:4px; color:#87505a; font-size:12px; }}
      code {{ background:#fff0f3; color:#7f1d2b; padding:3px 6px; border-radius:8px; }}
      .profile-mini {{ display:grid; grid-template-columns:1fr; gap:4px; color:#89414d; }}
      .profile-mini span {{ font-size:12px; font-weight:800; text-transform:uppercase; letter-spacing:.4px; }}
      .profile-mini b {{ color:#42131b; }}
      .roles-box {{ display:flex; flex-direction:column; gap:12px; }}
      .roles-list {{ display:flex; gap:6px; flex-wrap:wrap; }}
      .role-chip {{ display:inline-flex; align-items:center; gap:5px; background:#fff0f3; color:#c21e35; border:1px solid rgba(245,29,55,.14); padding:7px 9px; border-radius:999px; font-size:12px; font-weight:900; }}
      .role-chip form {{ display:inline; margin:0; }}
      .chip-x {{ width:20px; height:20px; padding:0; border-radius:50%; line-height:1; box-shadow:none; background:#f51d37; color:white; margin:0; }}
      .inline-form {{ display:grid; grid-template-columns:1fr auto; gap:8px; }}
      .inline-form button {{ margin:0; white-space:nowrap; }}
      .delete-form button {{ background:#42131b; box-shadow:none; white-space:nowrap; }}
      .empty-card {{ background:rgba(255,255,255,.78); border-radius:26px; padding:26px; box-shadow:0 18px 45px rgba(121,30,46,.12); }}
      .muted {{ color:#9a5a64; font-weight:700; }}
      @media(max-width:980px) {{
        .user-card {{ grid-template-columns:1fr; }}
        .search-row {{ grid-template-columns:1fr; }}
        .topbar {{ align-items:flex-start; flex-direction:column; }}
      }}
    </style>
    <div class='admin-shell'>
      <section class='topbar'>
        <div class='brand'>
          <div class='logo-dot'></div>
          <div><h1>KBEAUTY-DATA Admin</h1><p>Gestión limpia de usuarios y roles.</p></div>
        </div>
        <div class='actions'>
          <a class='btn ghost' href='/kbeauty-data/empleados'>Vista empleados</a>
          <a class='btn ghost' href='/kbeauty-data/logout'>Salir</a>
        </div>
      </section>

      <section class='summary'>
        <span>Sesión admin activa</span>
        <span>Roles: {escape(', '.join(sorted(codigos_roles(usuario))))}</span>
        <span>{len(usuarios)} usuarios visibles</span>
      </section>

      <section class='search-card'>
        <form method='get' action='/kbeauty-data/admin'>
          <label>Buscar usuario</label>
          <div class='search-row'>
            <input name='q' value='{escape(q or '')}' placeholder='Nombre, correo o Villar ID'>
            <button type='submit'>Buscar</button>
          </div>
        </form>
      </section>

      <section class='users-grid'>{filas}</section>
    </div>
    """
    return HTMLResponse(_html_base("KBEAUTY-DATA Admin", contenido, usuario, mostrar_nav=False))


@router.post("/kbeauty-data/admin/roles/asignar")
def accion_asignar_rol(request: Request, villar_id: str = Form(...), codigo_rol: str = Form(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    exigir_admin(usuario)
    asignar_rol_a_villar_id(villar_id, codigo_rol)
    return RedirectResponse("/kbeauty-data/admin", status_code=303)


@router.post("/kbeauty-data/admin/roles/quitar")
def accion_quitar_rol(request: Request, villar_id: str = Form(...), codigo_rol: str = Form(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    exigir_admin(usuario)
    quitar_rol_a_villar_id(villar_id, codigo_rol)
    return RedirectResponse("/kbeauty-data/admin", status_code=303)


@router.post("/kbeauty-data/admin/usuarios/eliminar")
def accion_eliminar_usuario(request: Request, villar_id: str = Form(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/admin")
    if redireccion:
        return redireccion
    exigir_admin(usuario)
    if str(usuario.get("villar_id")) == str(villar_id):
        return HTMLResponse(
            _html_base(
                "No permitido",
                "<div class='admin-shell'><div class='empty-card'><h1>No puedes eliminar tu propio usuario</h1><p>Usa otro administrador para esa operación.</p><a class='btn ghost' href='/kbeauty-data/admin'>Volver</a></div></div>",
                usuario,
                mostrar_nav=False,
            ),
            status_code=400,
        )
    eliminar_usuario_kbeauty(villar_id)
    return RedirectResponse("/kbeauty-data/admin", status_code=303)


@router.get("/kbeauty-data/empleados", response_class=HTMLResponse)
def vista_empleados(request: Request):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    if not usuario_tiene_rol(usuario, ROLES_EMPLEADO):
        return HTMLResponse(_html_base("Sin permiso", "<div class='card'><h1>Acceso denegado</h1><p>Tu usuario no tiene rol kbeauty_data.</p></div>", usuario), status_code=403)

    contenido = """
    <style>
      body {
        background:
          radial-gradient(circle at 20% 8%, rgba(255, 103, 119, .24), transparent 34%),
          radial-gradient(circle at 82% 24%, rgba(255, 213, 218, .58), transparent 30%),
          linear-gradient(180deg, #fff0f3 0%, #fff7f8 44%, #ffecef 100%) !important;
      }
      main.wrap { max-width:none; margin:0; padding:0; }
      .kd-shell {
        min-height:100vh;
        width:min(1180px, calc(100% - 44px));
        margin:0 auto;
        padding:28px 0 54px;
        background:transparent;
      }
      .app-top { display:flex; align-items:center; justify-content:space-between; margin-bottom:22px; }
      .app-brand { display:flex; gap:13px; align-items:center; }
      .app-brand b { display:block; font-size:22px; color:#28262d; letter-spacing:-.4px; }
      .app-brand small { display:block; color:#7d7680; font-weight:700; margin-top:2px; }
      .brand-icon, .logout-round {
        width:48px; height:48px; border-radius:19px; display:grid; place-items:center;
        background:#ffe0e5; color:#f51d37; font-weight:900; text-decoration:none;
        box-shadow:0 12px 26px rgba(245,29,55,.10);
      }
      .logout-round { background:#ffd8d2; color:#2b2a31; font-size:23px; }
      .kd-banner {
        position:relative;
        overflow:hidden;
        background:linear-gradient(135deg,#f51d37 0%, #ff4358 52%, #ff7480 100%);
        color:#fff; border-radius:34px; padding:36px 34px;
        box-shadow:0 28px 62px rgba(245,29,55,.27);
        margin-bottom:32px;
      }
      .kd-banner:after {
        content:""; position:absolute; width:220px; height:220px; border-radius:999px;
        right:-80px; top:-90px; background:rgba(255,255,255,.18);
      }
      .kd-banner h1 { margin:0; font-size:34px; line-height:1.05; letter-spacing:-.9px; }
      .kd-banner p { margin:13px 0 0; font-weight:800; line-height:1.45; color:#fff; max-width:560px; }
      .kd-content {
        display:grid;
        grid-template-columns:minmax(300px, 420px) minmax(0, 1fr);
        gap:24px;
        align-items:start;
      }
      .search-panel, .profile-card, .panel-card, .empty-state {
        background:rgba(255,255,255,.74);
        backdrop-filter:blur(18px);
        border:1px solid rgba(255,255,255,.82);
        box-shadow:0 22px 55px rgba(245,29,55,.10);
        border-radius:34px;
      }
      .search-panel { padding:24px; position:sticky; top:22px; }
      .upload-panel { margin-top:20px; padding-top:20px; border-top:1px solid rgba(255, 224, 229, .95); }
      .upload-panel h2 { margin:0; color:#28262d; letter-spacing:-.4px; }
      .upload-panel .upload-hint { margin:7px 0 14px; color:#7b7680; font-size:13px; font-weight:700; line-height:1.4; }
      .upload-panel.disabled { opacity:.58; }
      .upload-panel.disabled .drop-zone { cursor:not-allowed; }
      .upload-panel.disabled button[type=submit] { opacity:.55; cursor:not-allowed; box-shadow:none; }
      .kd-hero { text-align:left; padding:0; }
      .kd-title { font-size:30px; font-weight:950; margin:0; letter-spacing:-.9px; color:#28262d; }
      .kd-subtitle { color:#7b7680; margin:8px 0 0; line-height:1.45; font-weight:700; }
      .search-wrap { margin:22px 0 0; position:relative; }
      .search-box {
        display:flex; align-items:center; gap:12px; background:#fff; border:1px solid #ffe0e5;
        box-shadow:0 18px 38px rgba(255,42,65,.11); border-radius:25px; padding:10px 16px;
      }
      .search-icon { font-size:22px; opacity:.7; }
      #buscadorCliente { border:0; outline:none; margin:0; padding:15px 8px; font-size:16px; border-radius:20px; color:#2b2a31; background:transparent; }
      #buscadorCliente::placeholder { color:#8f8994; }
      .suggestions {
        position:absolute; left:0; right:0; top:74px; background:#fff; border:1px solid #ffe0e5;
        border-radius:26px; box-shadow:0 24px 62px rgba(245,29,55,.18); overflow:hidden; z-index:10; display:none;
      }
      .suggestion { padding:15px 18px; cursor:pointer; display:grid; grid-template-columns:1fr auto; gap:14px; border-bottom:1px solid #fff0f3; }
      .suggestion:hover { background:#fff3f5; }
      .suggestion:last-child { border-bottom:0; }
      .s-name { font-weight:950; color:#2b2a31; }
      .s-meta { color:#655f69; font-size:13px; margin-top:3px; word-break:break-word; }
      .s-id { color:#f51d37; font-size:12px; background:#ffecef; border-radius:999px; padding:7px 10px; align-self:center; font-weight:950; }
      .work-area { min-height:360px; }
      .empty-state { text-align:center; color:#7b7882; padding:42px 22px; }
      .empty-state b { display:block; color:#28262d; font-size:22px; margin-bottom:8px; }
      .client-layout { display:grid; grid-template-columns:minmax(280px,.82fr) minmax(0,1.18fr); gap:18px; align-items:start; margin-top:0; display:none; }
      .profile-card, .panel-card { padding:22px; }
      .avatar {
        width:66px; height:66px; border-radius:24px; display:grid; place-items:center;
        background:#ffe2e7; color:#f51d37; font-size:26px; font-weight:950;
        box-shadow:0 14px 30px rgba(245,29,55,.16);
      }
      .profile-top { display:flex; gap:16px; align-items:center; margin-bottom:18px; }
      .client-name { margin:0; font-size:23px; line-height:1.15; color:#28262d; letter-spacing:-.5px; }
      .client-email { color:#68616d; margin-top:5px; word-break:break-word; font-weight:700; }
      .info-line { padding:13px 0; border-top:1px solid #fff0f3; display:flex; justify-content:space-between; gap:14px; }
      .info-line span:first-child { color:#7b7680; font-weight:700; }
      .info-line b { text-align:right; color:#28262d; word-break:break-word; }
      .tabs-title { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:16px; }
      .tabs-title h2 { margin:0; color:#28262d; letter-spacing:-.4px; }
      .analysis-list { display:grid; gap:12px; margin-bottom:24px; }
      .analysis-item { border:1px solid #fff0f3; border-radius:22px; padding:15px; display:flex; justify-content:space-between; gap:12px; align-items:center; background:#fff; }
      .tag { display:inline-flex; align-items:center; border-radius:999px; padding:7px 11px; font-size:12px; font-weight:950; background:#ffecef; color:#f51d37; white-space:nowrap; }
      .tag.presencial { background:#ddfaf4; color:#12a999; }
      .drop-zone {
        border:2px dashed #ffc6d0; border-radius:28px; padding:30px; text-align:center;
        background:linear-gradient(180deg,#fff,#fff1f4); transition:.15s; cursor:pointer;
      }
      .drop-zone.drag { border-color:#f51d37; background:#ffe5ea; transform:scale(1.01); }
      .drop-zone input { display:none; }
      .drop-icon { font-size:44px; margin-bottom:8px; }
      .upload-row { display:flex; gap:12px; align-items:center; justify-content:center; flex-wrap:wrap; margin-top:16px; }
      button,.secondary-btn {
        border-radius:999px !important;
        padding:13px 18px !important;
      }
      .secondary-btn { background:#fff0f3 !important; color:#f51d37 !important; box-shadow:none !important; }
      .status { margin-top:14px; color:#6f6872; font-size:14px; font-weight:700; }
      .hidden { display:none !important; }
      .upload-splash { position:fixed; inset:0; z-index:9999; display:none; align-items:center; justify-content:center; padding:24px; background:rgba(255,240,243,.82); backdrop-filter:blur(14px); }
      .upload-splash.active { display:flex; }
      .upload-box { width:min(420px, calc(100% - 32px)); text-align:center; background:#fff; border-radius:34px; padding:34px 28px; box-shadow:0 32px 88px rgba(245,29,55,.22); border:1px solid #ffe0e5; }
      .upload-loader { width:72px; height:72px; border-radius:999px; margin:0 auto 18px; border:7px solid #ffe0e5; border-top-color:#f51d37; animation:girar .82s linear infinite; }
      .upload-box h2 { margin:0; color:#28262d; font-size:24px; }
      .upload-box p { color:#7b7680; font-weight:700; margin:10px 0 0; line-height:1.45; }
      @keyframes girar { to { transform:rotate(360deg); } }
      label { color:#28262d; }
      textarea { background:#fff; border:1px solid #ffe0e5; border-radius:22px; }
      @media(max-width:900px) {
        .kd-shell { width:min(430px, calc(100% - 26px)); padding:18px 0 36px; }
        .kd-content { grid-template-columns:1fr; }
        .search-panel { position:static; }
        .client-layout { grid-template-columns:1fr; }
        .kd-banner { padding:28px 22px; border-radius:30px; }
        .kd-banner h1 { font-size:29px; }
      }
    </style>

    <section class='kd-shell'>
      <div class='app-top'>
        <div class='app-brand'><span class='brand-icon'>☘</span><div><b>KBeauty IA</b><small>Panel empleados</small></div></div>
        <a class='logout-round' href='/kbeauty-data/logout' title='Salir'>↪</a>
      </div>
      <div class='kd-banner'>
        <h1>Hola, equipo luminoso</h1>
        <p>Busca el cliente y sube su análisis presencial en PDF.</p>
      </div>
      <div class='kd-content'>
        <aside class='search-panel'>
          <div class='kd-hero'>
            <h1 class='kd-title'>Buscar cliente</h1>
            <p class='kd-subtitle'>Escribe correo, nombre o Villar ID. Aparecerán coincidencias al instante.</p>
            <div class='search-wrap'>
              <div class='search-box'>
                <span class='search-icon'>🔎</span>
                <input id='buscadorCliente' autocomplete='off' placeholder='Correo, nombre o Villar ID'>
              </div>
              <div id='sugerencias' class='suggestions'></div>
            </div>
          </div>
          <div id='uploadPanel' class='upload-panel disabled'>
            <h2>Subir PDF presencial</h2>
            <p class='upload-hint' id='uploadHint'>Primero selecciona un cliente para activar la subida.</p>
            <form id='formPdf'>
              <input type='hidden' id='villarIdSeleccionado' name='villar_id'>
              <input type='hidden' id='perfilIdSeleccionado' name='perfil_id'>
              <label>Notas internas opcionales</label>
              <textarea id='notasPdf' name='notas' placeholder='Ej: análisis realizado en cabina, sucursal, observaciones...'></textarea>
              <label id='dropZone' class='drop-zone'>
                <input id='archivoPdf' name='archivo' type='file' accept='application/pdf'>
                <div class='drop-icon'>📄</div>
                <b>Arrastra el PDF aquí</b>
                <p class='small'>o toca para seleccionarlo. Solo se acepta PDF.</p>
                <div id='nombreArchivo' class='status'></div>
              </label>
              <div class='upload-row'>
                <button id='botonSubirPdf' type='submit' disabled>Subir PDF</button>
                <button type='button' id='limpiarSeleccion' class='secondary-btn'>Limpiar</button>
              </div>
              <div id='estadoUpload' class='status'></div>
            </form>
          </div>
        </aside>

        <section class='work-area'>
          <div id='estadoInicial' class='empty-state'><b>Selecciona un cliente</b>Su perfil, análisis y subida de PDF aparecerán aquí.</div>

          <section id='clienteLayout' class='client-layout'>
        <aside class='profile-card'>
          <div class='profile-top'>
            <div id='clienteAvatar' class='avatar'>K</div>
            <div>
              <h2 id='clienteNombre' class='client-name'>Cliente</h2>
              <div id='clienteCorreo' class='client-email'>Correo no disponible</div>
            </div>
          </div>
          <div class='info-line'><span>Villar ID</span><b id='clienteVillarId'>-</b></div>
          <div class='info-line'><span>ID KBeauty</span><b id='clienteKbeautyId'>-</b></div>
          <div class='info-line'><span>Tipo de piel</span><b id='clienteTipoPiel'>-</b></div>
          <div class='info-line'><span>Condición</span><b id='clienteCondicion'>-</b></div>
          <div class='info-line'><span>Sensibilidad</span><b id='clienteSensibilidad'>-</b></div>
        </aside>

        <div class='panel-card'>
          <div class='tabs-title'>
            <h2>Análisis del cliente</h2>
            <span id='contadorAnalisis' class='tag'>0 análisis</span>
          </div>
          <div id='listaAnalisis' class='analysis-list'></div>

        </div>
          </section>
        </section>
      </div>
    </section>

    <div id='uploadSplash' class='upload-splash' aria-hidden='true'>
      <div class='upload-box'>
        <div class='upload-loader'></div>
        <h2>Subiendo y analizando PDF</h2>
        <p>Estamos guardando el archivo y extrayendo los datos del análisis presencial. No cierres esta pantalla.</p>
      </div>
    </div>

    <script>
      const input = document.getElementById('buscadorCliente');
      const sugerencias = document.getElementById('sugerencias');
      const layout = document.getElementById('clienteLayout');
      const estadoInicial = document.getElementById('estadoInicial');
      const dropZone = document.getElementById('dropZone');
      const archivoPdf = document.getElementById('archivoPdf');
      const nombreArchivo = document.getElementById('nombreArchivo');
      const estadoUpload = document.getElementById('estadoUpload');
      const uploadPanel = document.getElementById('uploadPanel');
      const uploadHint = document.getElementById('uploadHint');
      const uploadSplash = document.getElementById('uploadSplash');
      const botonSubirPdf = document.getElementById('botonSubirPdf');
      let timer = null;
      let clienteActual = null;
      actualizarEstadoUploadPorCliente();

      function texto(v, fallback='-') { return v === null || v === undefined || v === '' ? fallback : v; }
      function iniciales(nombre) { return (nombre || 'K').split(' ').map(x => x[0]).join('').slice(0,2).toUpperCase(); }
      function fechaBonita(valor) {
        if (!valor) return '';
        const d = new Date(valor);
        if (Number.isNaN(d.getTime())) return valor;
        return d.toLocaleString();
      }

      function setSubidaActiva(activa) {
        uploadSplash.classList.toggle('active', activa);
        uploadSplash.setAttribute('aria-hidden', activa ? 'false' : 'true');
        botonSubirPdf.disabled = activa || !clienteActual;
        archivoPdf.disabled = activa || !clienteActual;
        document.getElementById('notasPdf').disabled = activa || !clienteActual;
        document.getElementById('limpiarSeleccion').disabled = activa;
      }

      function actualizarEstadoUploadPorCliente() {
        const hayCliente = !!clienteActual;
        uploadPanel.classList.toggle('disabled', !hayCliente);
        botonSubirPdf.disabled = !hayCliente;
        archivoPdf.disabled = !hayCliente;
        document.getElementById('notasPdf').disabled = !hayCliente;
        uploadHint.textContent = hayCliente
          ? `PDF para: ${clienteActual.villar_nombre || clienteActual.villar_correo || clienteActual.villar_id}`
          : 'Primero selecciona un cliente para activar la subida.';
      }

      async function fetchSeguro(url, opciones = {}) {
        const res = await fetch(url, opciones);
        if (res.redirected || (res.url && res.url.includes('/kbeauty-data/login'))) {
          window.location.href = res.url || '/kbeauty-data/logout';
          throw new Error('Sesion vencida. Redirigiendo al login...');
        }
        if (res.status === 401) {
          window.location.href = '/kbeauty-data/logout';
          throw new Error('Sesion vencida. Redirigiendo al login...');
        }
        return res;
      }

      input.addEventListener('input', () => {
        const q = input.value.trim();
        clearTimeout(timer);
        if (q.length < 2) { sugerencias.style.display = 'none'; return; }
        timer = setTimeout(() => buscarSugerencias(q), 260);
      });

      async function buscarSugerencias(q) {
        sugerencias.innerHTML = `<div class='suggestion'><div><b>Buscando...</b><div class='s-meta'>Un momento</div></div></div>`;
        sugerencias.style.display = 'block';
        try {
          const res = await fetchSeguro(`/kbeauty-data/clientes/buscar?q=${encodeURIComponent(q)}`);
          const data = await res.json();
          const items = data.datos || [];
          if (!items.length) {
            sugerencias.innerHTML = `<div class='suggestion'><div><b>No hay resultados</b><div class='s-meta'>Prueba con correo, nombre o Villar ID.</div></div></div>`;
            return;
          }
          sugerencias.innerHTML = items.map(c => {
            const nombre = c.villar_nombre || 'Sin nombre';
            const correo = c.villar_correo || 'Correo no disponible';
            const vid = c.villar_id || '';
            return `<div class='suggestion' data-villar='${vid}'>
              <div><div class='s-name'>${nombre}</div><div class='s-meta'>${correo}</div><div class='s-meta'>${vid}</div></div>
              <div class='s-id'>Seleccionar</div>
            </div>`;
          }).join('');
          document.querySelectorAll('.suggestion[data-villar]').forEach(el => {
            el.addEventListener('click', () => seleccionarCliente(el.dataset.villar));
          });
        } catch (e) {
          sugerencias.innerHTML = `<div class='suggestion'><div><b>Error buscando</b><div class='s-meta'>${e}</div></div></div>`;
        }
      }

      async function seleccionarCliente(villarId) {
        sugerencias.style.display = 'none';
        input.value = villarId;
        estadoInicial.classList.add('hidden');
        layout.style.display = 'grid';
        document.getElementById('listaAnalisis').innerHTML = `<div class='analysis-item'>Cargando cliente...</div>`;
        const res = await fetchSeguro(`/kbeauty-data/clientes/${encodeURIComponent(villarId)}/detalle`);
        const data = await res.json();
        if (!data.correcto) { alert(data.mensaje || 'No se pudo cargar'); return; }
        clienteActual = data.datos;
        pintarCliente(clienteActual);
        actualizarEstadoUploadPorCliente();
      }

      function pintarCliente(c) {
        const nombre = c.villar_nombre || 'Sin nombre';
        document.getElementById('clienteAvatar').textContent = iniciales(nombre);
        document.getElementById('clienteNombre').textContent = nombre;
        document.getElementById('clienteCorreo').textContent = c.villar_correo || 'Correo no disponible';
        document.getElementById('clienteVillarId').textContent = texto(c.villar_id);
        document.getElementById('clienteKbeautyId').textContent = texto(c.id);
        const p = c.perfil || {};
        document.getElementById('clienteTipoPiel').textContent = texto(p.tipo_piel);
        document.getElementById('clienteCondicion').textContent = texto(p.condicion_principal);
        document.getElementById('clienteSensibilidad').textContent = texto(p.sensibilidad);
        document.getElementById('villarIdSeleccionado').value = c.villar_id || '';
        document.getElementById('perfilIdSeleccionado').value = p.id || '';
        const analisis = c.analisis || [];
        document.getElementById('contadorAnalisis').textContent = `${analisis.length} análisis`;
        document.getElementById('listaAnalisis').innerHTML = analisis.length ? analisis.map(a => `
          <div class='analysis-item'>
            <div>
              <b>${a.resumen_general || a.archivo_nombre || 'Análisis facial'}</b>
              <div class='small'>${fechaBonita(a.creado_en)}</div>
              <div class='small'>${a.condicion_principal_detectada || a.estado_procesamiento || ''}</div>
            </div>
            <span class='tag ${a.tipo === 'presencial_pdf' ? 'presencial' : ''}'>${a.etiqueta || a.tipo}</span>
          </div>`).join('') : `<div class='analysis-item'><div><b>Sin análisis todavía</b><div class='small'>Cuando subas el PDF aparecerá aquí.</div></div></div>`;
      }

      archivoPdf.addEventListener('change', () => validarArchivo());
      ['dragenter','dragover'].forEach(ev => dropZone.addEventListener(ev, e => { e.preventDefault(); dropZone.classList.add('drag'); }));
      ['dragleave','drop'].forEach(ev => dropZone.addEventListener(ev, e => { e.preventDefault(); dropZone.classList.remove('drag'); }));
      dropZone.addEventListener('drop', e => {
        const file = e.dataTransfer.files[0];
        if (file) { archivoPdf.files = e.dataTransfer.files; validarArchivo(); }
      });
      function validarArchivo() {
        const file = archivoPdf.files[0];
        if (!file) { nombreArchivo.textContent = ''; return false; }
        if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
          archivoPdf.value = '';
          nombreArchivo.textContent = 'Solo se acepta PDF.';
          return false;
        }
        nombreArchivo.textContent = `Seleccionado: ${file.name}`;
        return true;
      }

      document.getElementById('limpiarSeleccion').addEventListener('click', () => {
        archivoPdf.value = '';
        document.getElementById('notasPdf').value = '';
        nombreArchivo.textContent = '';
        estadoUpload.textContent = '';
      });

      document.getElementById('formPdf').addEventListener('submit', async e => {
        e.preventDefault();
        if (!clienteActual) { alert('Selecciona un cliente primero.'); return; }
        if (!validarArchivo()) return;
        const form = new FormData(e.target);
        estadoUpload.textContent = 'Subiendo y analizando PDF...';
        setSubidaActiva(true);
        try {
          const res = await fetchSeguro('/kbeauty-data/analisis-presencial/subir', { method:'POST', body:form });
          const data = await res.json();
          if (!res.ok || !data.correcto) throw new Error((data.detail && data.detail.mensaje) || data.mensaje || 'Error subiendo PDF');
          estadoUpload.textContent = 'PDF subido correctamente.';
          archivoPdf.value = '';
          nombreArchivo.textContent = '';
          await seleccionarCliente(clienteActual.villar_id);
        } catch (err) {
          estadoUpload.textContent = err.message || 'Error subiendo PDF.';
        } finally {
          setSubidaActiva(false);
        }
      });
    </script>
    """
    return HTMLResponse(_html_base("KBEAUTY-DATA Empleados", contenido, usuario, mostrar_nav=False))


@router.post("/kbeauty-data/analisis-presencial/subir-web")
def subir_pdf_web(request: Request, villar_id: str = Form(...), perfil_id: str = Form(None), notas: str = Form(""), archivo: UploadFile = File(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    guardar_pdf_presencial(villar_id, usuario.get("villar_id"), archivo, perfil_id=perfil_id or None, notas=notas)
    return RedirectResponse("/kbeauty-data/empleados", status_code=303)


@router.get("/kbeauty-data/clientes/{villar_id}/detalle")
def api_detalle_cliente_kdata(request: Request, villar_id: str):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    return respuesta_correcta(
        "Cliente encontrado",
        obtener_cliente_kdata(villar_id, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar")),
    )


@router.get("/kbeauty-data/clientes/buscar")
def api_buscar_clientes(request: Request, q: str = Query(..., min_length=1)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    return respuesta_correcta("Clientes encontrados", buscar_clientes(q, token=usuario.get("token_villar_do"), datos_sesion=usuario.get("datos_villar")))


@router.post("/kbeauty-data/analisis-presencial/subir")
def api_subir_pdf(request: Request, villar_id: str = Form(...), perfil_id: str = Form(None), notas: str = Form(""), archivo: UploadFile = File(...)):
    usuario, redireccion = _usuario_web_o_redirect(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    exigir_empleado(usuario)
    registro = guardar_pdf_presencial(villar_id, usuario.get("villar_id"), archivo, perfil_id=perfil_id or None, notas=notas)
    return respuesta_correcta("PDF presencial subido", registro)


@router.get("/analisis-presencial/{analisis_id}")
def api_detalle_presencial(request: Request, analisis_id: str):
    usuario, redireccion = _usuario_web_o_bearer(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    fila = obtener_pdf_presencial(analisis_id, usuario)
    return respuesta_correcta("Analisis presencial", fila)


@router.get("/analisis-presencial/{analisis_id}/pdf")
def api_ver_pdf_presencial(request: Request, analisis_id: str):
    usuario, redireccion = _usuario_web_o_bearer(request, "/kbeauty-data/empleados")
    if redireccion:
        return redireccion
    fila = obtener_pdf_presencial(analisis_id, usuario)
    return FileResponse(
        fila["archivo_ruta"],
        media_type="application/pdf",
        filename=fila.get("archivo_nombre") or "analisis.pdf",
    )
