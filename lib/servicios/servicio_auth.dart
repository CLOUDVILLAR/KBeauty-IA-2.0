import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/config.dart';
import 'servicio_api.dart';

class ServicioAuth {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _suscripcionLinks;
  static HttpServer? _servidorCallbackEscritorio;
  static bool _procesandoCallback = false;
  static int _estadoActual = 0;

  static Future<void> inicializarEscuchaCallback({
    required Future<void> Function() alIniciarSesion,
    void Function(String mensaje)? alError,
  }) async {
    await _suscripcionLinks?.cancel();

    try {
      final Uri? enlaceInicial = await _appLinks.getInitialLink();
      if (enlaceInicial != null) {
        final procesado = await procesarCallbackVillarDo(enlaceInicial);
        if (procesado) await alIniciarSesion();
      }
    } catch (error) {
      alError?.call('No se pudo leer el enlace inicial: $error');
    }

    _suscripcionLinks = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        try {
          final procesado = await procesarCallbackVillarDo(uri);
          if (procesado) await alIniciarSesion();
        } catch (error) {
          alError?.call('No se pudo procesar Villar.do: $error');
        }
      },
      onError: (error) {
        alError?.call('No se pudo procesar el regreso de Villar.do: $error');
      },
    );
  }

  static Future<void> cerrarEscuchaCallback() async {
    await _suscripcionLinks?.cancel();
    _suscripcionLinks = null;
  }

  static Future<void> cancelarAutenticacionWeb() async {
    try {
      await _servidorCallbackEscritorio?.close(force: true);
    } catch (_) {}
    _servidorCallbackEscritorio = null;
    _estadoActual++;
  }

  /// Abre el flujo SSO de Villar.do.
  ///
  /// Devuelve true cuando la sesion quedo procesada dentro de esta llamada
  /// (desktop con callback local). En movil devuelve false porque el navegador
  /// regresa luego por deep link y lo procesa inicializarEscuchaCallback().
  static Future<bool> abrirLoginVillarDo() async {
    return _abrirFormularioVillarDo('/login');
  }

  /// Igual que abrirLoginVillarDo(), pero usando el formulario web de registro.
  static Future<bool> abrirRegistroVillarDo() async {
    return _abrirFormularioVillarDo('/registro');
  }

  static Future<void> abrirRecuperarPassword() async {
    final uri = Uri.parse('$urlVillarDo/recuperar').replace(
      queryParameters: {
        'client_id': clienteVillarDo,
        'app_key': villarDoAppKey,
      },
    );
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto) throw Exception('No se pudo abrir la recuperacion de Villar.do');
  }

  static bool get _esEscritorio {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _abrirFormularioVillarDo(String ruta) async {
    // El usuario esta iniciando un flujo nuevo de Villar.do.
    // Si venimos de un logout reciente, quitamos el bloqueo temporal para
    // no rechazar el callback nuevo como si fuera un callback viejo.
    await desbloquearCallbacksVillarDo();
    await cancelarAutenticacionWeb();
    _estadoActual++;
    final estado = _estadoActual.toString();

    if (_esEscritorio) {
      return _abrirFormularioVillarDoEscritorio(ruta, estado);
    }

    final uri = Uri.parse('$urlVillarDo$ruta').replace(
      queryParameters: {
        'client_id': clienteVillarDo,
        'app_key': villarDoAppKey,
        'redirect_uri': callbackVillarDo,
        'estado': estado,
      },
    );

    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto) throw Exception('No se pudo abrir Villar.do');
    return false;
  }

  static Future<bool> _abrirFormularioVillarDoEscritorio(String ruta, String estado) async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _servidorCallbackEscritorio = servidor;
    final redirectUri = 'http://127.0.0.1:${servidor.port}/callback';

    final uri = Uri.parse('$urlVillarDo$ruta').replace(
      queryParameters: {
        'client_id': clienteVillarDo,
        'app_key': villarDoAppKey,
        'redirect_uri': redirectUri,
        'estado': estado,
      },
    );

    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto) {
      await cancelarAutenticacionWeb();
      throw Exception('No se pudo abrir Villar.do');
    }

    try {
      final solicitud = await _esperarSolicitudCallback(servidor).timeout(
        tiempoEsperaSso,
        onTimeout: () {
          throw TimeoutException('Tiempo agotado esperando Villar.do. Puedes intentar de nuevo.');
        },
      );

      final procesado = await procesarCallbackVillarDo(solicitud.uri);

      solicitud.response.statusCode = 200;
      solicitud.response.headers.contentType = ContentType.html;
      solicitud.response.write(_htmlRespuestaCallback(procesado));
      await solicitud.response.close();

      if (!procesado) throw Exception('Villar.do no devolvio una sesion valida');
      return true;
    } on SocketException {
      throw Exception('Se canceló el inicio de sesión');
    } finally {
      await cancelarAutenticacionWeb();
    }
  }

  static Future<HttpRequest> _esperarSolicitudCallback(HttpServer servidor) async {
    await for (final solicitud in servidor) {
      final path = solicitud.uri.path;
      final tieneToken = solicitud.uri.queryParameters.containsKey('access_token') ||
          solicitud.uri.queryParameters.containsKey('token') ||
          solicitud.uri.queryParameters.containsKey('error');

      // En Windows algunos navegadores vuelven a /callback y otros a / si el
      // redirect_uri fue normalizado. Aceptamos ambos siempre que traigan datos
      // de autenticacion. Ignoramos favicon y peticiones decorativas.
      if (path.startsWith('/callback') || (path == '/' && tieneToken)) {
        return solicitud;
      }

      solicitud.response.statusCode = 204;
      await solicitud.response.close();
    }
    throw Exception('El navegador cerró la conexión antes de iniciar sesión');
  }

  static String _htmlRespuestaCallback(bool procesado) {
    final titulo = procesado ? 'Sesión iniciada' : 'No se pudo iniciar sesión';
    final mensaje = procesado
        ? 'Ya puedes volver a KBeauty IA. Esta ventana se puede cerrar.'
        : 'Vuelve a la app e intenta nuevamente.';
    return '''<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>Villar.do</title>
  <style>
    body{font-family:Arial,sans-serif;background:#fff;color:#222;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
    .card{border:1px solid #eee;border-radius:24px;padding:32px;box-shadow:0 18px 60px rgba(0,0,0,.08);text-align:center;max-width:440px}
    .brand{color:#eb4d2f;font-weight:800;font-size:28px;margin-bottom:8px}
    p{line-height:1.5;color:#555}
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">Villar.do</div>
    <h2>$titulo</h2>
    <p>$mensaje</p>
    <script>setTimeout(function(){ window.close(); }, 1200);</script>
  </div>
</body>
</html>''';
  }

 static bool _esCallbackVillarDo(Uri uri) {
  final callback = Uri.parse(callbackVillarDo);

  final esMovil = uri.scheme == callback.scheme &&
      uri.host == callback.host &&
      uri.path.startsWith(callback.path);

  final tieneToken = uri.queryParameters.containsKey('access_token') ||
      uri.queryParameters.containsKey('token') ||
      uri.queryParameters.containsKey('error');

  final esEscritorio = (uri.scheme == 'http' || uri.scheme.isEmpty) &&
      (uri.path.startsWith('/callback') || (uri.path == '/' && tieneToken));

  return esMovil || esEscritorio;
}

  static Future<bool> procesarCallbackVillarDo(Uri uri) async {
    if (!_esCallbackVillarDo(uri)) return false;
    if (await hayCierreSesionEnCurso()) return false;
    if (await callbackEstaBloqueado()) return false;
    if (_procesandoCallback) return false;
    _procesandoCallback = true;

    try {
      final firmaCallback = uri.toString();
      final ultimoProcesado = await obtenerUltimoCallbackProcesado();
      if (ultimoProcesado == firmaCallback) return false;

      final error = uri.queryParameters['error'];
      if (error != null && error.isNotEmpty) {
        await guardarUltimoCallbackProcesado(firmaCallback);
        throw Exception(error);
      }

      final accessToken = _leerParametro(uri, ['access_token', 'token']);
      var refreshToken = _leerParametro(uri, ['refresh_token']);
      var villarId = _leerParametro(uri, ['villar_id', 'usuario_id']);

      if (accessToken == null || accessToken.isEmpty) {
        await guardarUltimoCallbackProcesado(firmaCallback);
        return false;
      }

      villarId ??= _extraerVillarIdDesdeJwt(accessToken);
      refreshToken ??= '';

      if (villarId == null || villarId.isEmpty) {
        await guardarUltimoCallbackProcesado(firmaCallback);
        return false;
      }

      await guardarToken(accessToken);
      if (refreshToken.isNotEmpty) await guardarRefreshToken(refreshToken);
      await guardarVillarId(villarId);
      await guardarUltimoCallbackProcesado(firmaCallback);

      await asegurarUsuarioKBeauty();
      return true;
    } finally {
      _procesandoCallback = false;
    }
  }

  static String? _leerParametro(Uri uri, List<String> nombres) {
    for (final nombre in nombres) {
      final valor = uri.queryParameters[nombre];
      if (valor != null && valor.isNotEmpty && valor != 'None' && valor != 'null') return valor;
    }
    return null;
  }

  static String? _extraerVillarIdDesdeJwt(String token) {
    try {
      final partes = token.split('.');
      if (partes.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
      final datos = jsonDecode(payload);
      if (datos is! Map) return null;
      for (final clave in ['villar_id', 'usuario_id', 'sub', 'id']) {
        final valor = datos[clave]?.toString();
        if (valor != null && valor.isNotEmpty) return valor;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> haySesion() async {
    final token = await obtenerToken();
    var villarId = await obtenerVillarId();
    if ((villarId == null || villarId.isEmpty) && token != null && token.isNotEmpty) {
      villarId = _extraerVillarIdDesdeJwt(token);
      if (villarId != null && villarId.isNotEmpty) await guardarVillarId(villarId);
    }
    return token != null && token.isNotEmpty && villarId != null && villarId.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> usuarioActual() async {
    try {
      return await obtenerUsuarioActual();
    } catch (_) {
      return null;
    }
  }

  static Future<void> asegurarUsuarioKBeauty() async {
    final token = await obtenerToken();
    if (token == null || token.isEmpty) return;

    final posiblesRutas = <String>[
      crearUrl('/auth/me'),
      crearUrl('/usuarios/me'),
      crearUrl(rutaPerfilUsuario),
      crearUrl(rutaEstadoPerfil),
    ];

    for (final ruta in posiblesRutas) {
      try {
        final respuesta = await http.get(
          Uri.parse(ruta),
          headers: crearCabeceras(token: token),
        ).timeout(const Duration(seconds: 8));
        if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return;
      } catch (_) {}
    }
  }

  static Future<void> cerrarSesion() async {
    await cerrarSesionLocalYServidor();
  }
}

Future<Map<String, dynamic>> registrarUsuario({
  required String nombre,
  required String apellido,
  required String correo,
  required String contrasena,
  String telefono = '',
  String pais = '',
  String ciudad = '',
}) async {
  final respuesta = await enviarPost(
    rutaRegistro,
    {
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      'contrasena': contrasena,
      'password': contrasena,
      'telefono': telefono,
      'pais': pais,
      'ciudad': ciudad,
    },
    requiereToken: false,
  );
  final datos = Map<String, dynamic>.from(datosDe(respuesta) ?? respuesta);
  await _guardarSesionDesdeRespuesta(datos);
  return datos;
}

Future<Map<String, dynamic>> iniciarSesion(String correo, String contrasena) async {
  final respuesta = await enviarPost(
    rutaLogin,
    {'correo': correo, 'contrasena': contrasena, 'password': contrasena},
    requiereToken: false,
  );
  final datos = Map<String, dynamic>.from(datosDe(respuesta) ?? respuesta);
  await _guardarSesionDesdeRespuesta(datos);
  return datos;
}

Future<void> _guardarSesionDesdeRespuesta(Map<String, dynamic> datos) async {
  final usuario = datos['usuario'];
  final usuarioMapa = usuario is Map ? Map<String, dynamic>.from(usuario) : <String, dynamic>{};

  final token = datos['token']?.toString() ?? datos['access_token']?.toString();
  final refreshToken = datos['refresh_token']?.toString();
  final villarId = datos['villar_id']?.toString() ?? usuarioMapa['villar_id']?.toString();

  if (token != null && token.isNotEmpty) await guardarToken(token);
  if (refreshToken != null && refreshToken.isNotEmpty) await guardarRefreshToken(refreshToken);
  if (villarId != null && villarId.isNotEmpty) await guardarVillarId(villarId);
}

Future<Map<String, dynamic>> refrescarSesion() async {
  final refreshToken = await obtenerRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) throw Exception('No hay refresh token guardado');
  final respuesta = await enviarPost(rutaRefresh, {'refresh_token': refreshToken}, requiereToken: false);
  final datos = Map<String, dynamic>.from(datosDe(respuesta) ?? respuesta);
  await _guardarSesionDesdeRespuesta(datos);
  return datos;
}

Future<Map<String, dynamic>> obtenerUsuarioActual() async {
  final respuesta = await enviarGet(rutaPerfilUsuario);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? respuesta);
}

Future<void> cerrarSesion() async => ServicioAuth.cerrarSesion();

Future<void> cerrarSesionLocalYServidor() async {
  await marcarCierreSesionEnCurso(true);
  await bloquearCallbacksTemporalmente(segundos: 30);
  await ServicioAuth.cerrarEscuchaCallback();
  await ServicioAuth.cancelarAutenticacionWeb();

  final refreshToken = await obtenerRefreshToken();
  try {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await enviarPost(rutaLogout, {'refresh_token': refreshToken}, requiereToken: false);
    }
  } catch (_) {}

  await borrarSesionLocalYVerificar();
  await Future.delayed(const Duration(milliseconds: 700));
  await marcarCierreSesionEnCurso(false);
}

Future<Map<String, dynamic>> solicitarRecuperacionContrasena(String correo) async {
  return enviarPostExterno(crearUrlVillarDo(rutaVillarRecuperar), {'correo': correo});
}

Future<Map<String, dynamic>> cambiarContrasenaConToken(String token, String nuevaContrasena) async {
  return enviarPostExterno(crearUrlVillarDo(rutaVillarCambiarPassword), {'token': token, 'nueva_contrasena': nuevaContrasena});
}
