const String urlApi = String.fromEnvironment(
  'URL_API',
  defaultValue: 'http://10.0.0.179:8000',
);

const String urlVillarDo = String.fromEnvironment(
  'URL_VILLAR_DO',
  defaultValue: 'http://3.143.67.15:8100/',
);

const String villarDoAppKey =
    'villar_sk_dev_bdfdsBFgP0FTxulLvSWLAZ4JU6S9DDhq87-dw_l6PJGIXUo8';

const Duration tiempoEsperaApi = Duration(seconds: 90);
const Duration tiempoEsperaSso = Duration(minutes: 15);

const String nombreToken = 'token_kbeauty_villar_do';
const String nombreRefreshToken = 'refresh_token_kbeauty_villar_do';
const String nombreVillarId = 'villar_id_kbeauty';
const String nombreUltimoCallbackVillarDo = 'ultimo_callback_villar_do_procesado';
const String nombreCierreSesionEnCurso = 'cierre_sesion_en_curso_kbeauty';
const String nombreBloqueoCallbackHasta = 'bloqueo_callback_villar_do_hasta';

const String clienteVillarDo = 'kbeauty_ia_5';
const String callbackVillarDo = 'kbeauty://auth/callback';

const String rutaRegistro = '/usuarios/registro';
const String rutaLogin = '/usuarios/login';
const String rutaRefresh = '/usuarios/refresh';
const String rutaLogout = '/usuarios/logout';
const String rutaPerfilUsuario = '/usuarios/perfil';
const String rutaEstadoPerfil = '/perfil/estado';
const String rutaOpcionesPerfil = '/perfil/opciones';
const String rutaFormularioPerfil = '/perfil/formulario';
const String rutaNuevoAnalisis = '/analisis/nuevo';
const String rutaHistorialAnalisis = '/analisis/historial';
const String rutaRutinaRecomendada = '/rutinas/recomendada';
const String rutaEvolucionResumen = '/evolucion/resumen';
const String rutaEvolucionHistorial = '/evolucion/historial';
const String rutaChatMensajes = '/chat/mensajes';
const String rutaChatMensaje = '/chat/mensaje';

const String rutaVillarRecuperar = '/api/auth/recuperar';
const String rutaVillarCambiarPassword = '/api/auth/cambiar-password';

String crearUrl(String ruta) => '$urlApi$ruta';
String crearUrlVillarDo(String ruta) => '$urlVillarDo$ruta';
