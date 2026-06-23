import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

const _almacenSeguro = FlutterSecureStorage();
Future<bool>? _refreshEnCurso;

class SesionExpiradaException implements Exception {
  const SesionExpiradaException([this.mensaje = 'Tu sesión expiró. Inicia sesión nuevamente con Villar.do.']);

  final String mensaje;

  @override
  String toString() => mensaje;
}

Future<void> guardarToken(String token) async {
  await _almacenSeguro.write(key: nombreToken, value: token);
}

Future<String?> obtenerToken() async {
  return _almacenSeguro.read(key: nombreToken);
}

Future<void> guardarRefreshToken(String token) async {
  await _almacenSeguro.write(key: nombreRefreshToken, value: token);
}

Future<String?> obtenerRefreshToken() async {
  return _almacenSeguro.read(key: nombreRefreshToken);
}

Future<void> guardarVillarId(String villarId) async {
  await _almacenSeguro.write(key: nombreVillarId, value: villarId);
}

Future<String?> obtenerVillarId() async {
  return _almacenSeguro.read(key: nombreVillarId);
}

Future<void> guardarUltimoCallbackProcesado(String callback) async {
  await _almacenSeguro.write(key: nombreUltimoCallbackVillarDo, value: callback);
}

Future<String?> obtenerUltimoCallbackProcesado() async {
  return _almacenSeguro.read(key: nombreUltimoCallbackVillarDo);
}

Future<void> marcarCierreSesionEnCurso(bool activo) async {
  if (activo) {
    await _almacenSeguro.write(key: nombreCierreSesionEnCurso, value: 'true');
  } else {
    await _almacenSeguro.delete(key: nombreCierreSesionEnCurso);
  }
}

Future<bool> hayCierreSesionEnCurso() async {
  final valor = await _almacenSeguro.read(key: nombreCierreSesionEnCurso);
  return valor == 'true';
}

Future<void> bloquearCallbacksTemporalmente({int segundos = 25}) async {
  final hasta = DateTime.now().add(Duration(seconds: segundos)).millisecondsSinceEpoch.toString();
  await _almacenSeguro.write(key: nombreBloqueoCallbackHasta, value: hasta);
}

Future<void> desbloquearCallbacksVillarDo() async {
  await _almacenSeguro.delete(key: nombreCierreSesionEnCurso);
  await _almacenSeguro.delete(key: nombreBloqueoCallbackHasta);
}

Future<bool> callbackEstaBloqueado() async {
  final valor = await _almacenSeguro.read(key: nombreBloqueoCallbackHasta);
  if (valor == null || valor.isEmpty) return false;
  final hasta = int.tryParse(valor) ?? 0;
  if (hasta <= 0) return false;
  final ahora = DateTime.now().millisecondsSinceEpoch;
  if (ahora <= hasta) return true;
  await _almacenSeguro.delete(key: nombreBloqueoCallbackHasta);
  return false;
}

Future<void> borrarSesionLocal() async {
  // Borrado agresivo: algunas plataformas tardan unas fracciones de segundo
  // en confirmar la escritura/eliminacion del almacenamiento seguro.
  for (var intento = 0; intento < 3; intento++) {
    await _almacenSeguro.delete(key: nombreToken);
    await _almacenSeguro.delete(key: nombreRefreshToken);
    await _almacenSeguro.delete(key: nombreVillarId);

    // Llaves antiguas usadas por versiones previas.
    await _almacenSeguro.delete(key: 'token');
    await _almacenSeguro.delete(key: 'access_token');
    await _almacenSeguro.delete(key: 'refresh_token');
    await _almacenSeguro.delete(key: 'villar_id');
    await _almacenSeguro.delete(key: 'usuario_id');

    await Future.delayed(const Duration(milliseconds: 180));
  }

  // NO borramos nombreUltimoCallbackVillarDo ni nombreBloqueoCallbackHasta.
  // Esos son los candados que evitan que Android reprocesa el ultimo link.
}

Future<void> borrarSesionLocalYVerificar() async {
  await borrarSesionLocal();

  for (var intento = 0; intento < 8; intento++) {
    final token = await obtenerToken();
    final refresh = await obtenerRefreshToken();
    final villarId = await obtenerVillarId();

    if ((token == null || token.isEmpty) &&
        (refresh == null || refresh.isEmpty) &&
        (villarId == null || villarId.isEmpty)) {
      return;
    }

    await borrarSesionLocal();
    await Future.delayed(const Duration(milliseconds: 250));
  }
}

Future<void> borrarToken() => borrarSesionLocal();

Map<String, String> crearCabeceras({bool json = true, String? token}) {
  final cabeceras = <String, String>{'Accept': 'application/json'};
  if (json) cabeceras['Content-Type'] = 'application/json';
  if (villarDoAppKey.isNotEmpty) {
    cabeceras['X-Villar-App-Key'] = villarDoAppKey;
    cabeceras['X-Villar-Client-Id'] = clienteVillarDo;
    cabeceras['X-Villar-Api-Key'] = villarDoAppKey;
  }
  if (token != null && token.isNotEmpty) {
    cabeceras['Authorization'] = 'Bearer $token';
  }
  return cabeceras;
}

Future<Map<String, dynamic>> enviarGet(String ruta, {bool requiereToken = true}) async {
  Future<http.Response> ejecutarPeticion(String? token) {
    return http
        .get(Uri.parse(crearUrl(ruta)), headers: crearCabeceras(token: token))
        .timeout(tiempoEsperaApi);
  }

  final respuesta = await _enviarConRefreshSiHaceFalta(
    ejecutarPeticion,
    requiereToken: requiereToken,
  );
  return procesarRespuesta(respuesta);
}

Future<Map<String, dynamic>> enviarPost(
  String ruta,
  Map<String, dynamic> datos, {
  bool requiereToken = true,
}) async {
  Future<http.Response> ejecutarPeticion(String? token) {
    return http
        .post(
          Uri.parse(crearUrl(ruta)),
          headers: crearCabeceras(token: token),
          body: jsonEncode(datos),
        )
        .timeout(tiempoEsperaApi);
  }

  final respuesta = await _enviarConRefreshSiHaceFalta(
    ejecutarPeticion,
    requiereToken: requiereToken,
  );
  return procesarRespuesta(respuesta);
}

Future<Map<String, dynamic>> enviarPostExterno(
  String url,
  Map<String, dynamic> datos, {
  String? token,
}) async {
  final respuesta = await http
      .post(
        Uri.parse(url),
        headers: crearCabeceras(token: token),
        body: jsonEncode(datos),
      )
      .timeout(tiempoEsperaApi);
  return procesarRespuesta(respuesta);
}

Future<Map<String, dynamic>> enviarImagen(String ruta, File imagen) async {
  return enviarTresImagenes(
    ruta,
    frente: imagen,
    ladoIzquierdo: imagen,
    ladoDerecho: imagen,
  );
}

Future<Map<String, dynamic>> enviarTresImagenes(
  String ruta, {
  required File frente,
  required File ladoIzquierdo,
  required File ladoDerecho,
}) async {
  Future<http.Response> ejecutarPeticion(String? token) async {
    final solicitud = http.MultipartRequest('POST', Uri.parse(crearUrl(ruta)));

    if (token != null && token.isNotEmpty) {
      solicitud.headers['Authorization'] = 'Bearer $token';
    }
    solicitud.headers['Accept'] = 'application/json';
    if (villarDoAppKey.isNotEmpty) {
      solicitud.headers['X-Villar-App-Key'] = villarDoAppKey;
      solicitud.headers['X-Villar-Client-Id'] = clienteVillarDo;
      solicitud.headers['X-Villar-Api-Key'] = villarDoAppKey;
    }

    solicitud.files.add(await http.MultipartFile.fromPath('frente', frente.path));
    solicitud.files.add(await http.MultipartFile.fromPath('lado_izquierdo', ladoIzquierdo.path));
    solicitud.files.add(await http.MultipartFile.fromPath('lado_derecho', ladoDerecho.path));

    final enviada = await solicitud.send().timeout(tiempoEsperaApi);
    return http.Response.fromStream(enviada);
  }

  final respuesta = await _enviarConRefreshSiHaceFalta(
    ejecutarPeticion,
    requiereToken: true,
  );
  return procesarRespuesta(respuesta);
}

Future<http.Response> _enviarConRefreshSiHaceFalta(
  Future<http.Response> Function(String? token) ejecutarPeticion, {
  required bool requiereToken,
}) async {
  String? token = requiereToken ? await obtenerToken() : null;
  var respuesta = await ejecutarPeticion(token);

  if (!requiereToken || respuesta.statusCode != 401) {
    return respuesta;
  }

  final refrescado = await refrescarSesionSiHaceFalta();
  if (!refrescado) {
    await borrarSesionLocalYVerificar();
    throw const SesionExpiradaException();
  }

  token = await obtenerToken();
  respuesta = await ejecutarPeticion(token);

  if (respuesta.statusCode == 401) {
    await borrarSesionLocalYVerificar();
    throw const SesionExpiradaException();
  }

  return respuesta;
}

Future<bool> refrescarSesionSiHaceFalta() async {
  if (_refreshEnCurso != null) return _refreshEnCurso!;

  _refreshEnCurso = _refrescarSesionInterno();
  try {
    return await _refreshEnCurso!;
  } finally {
    _refreshEnCurso = null;
  }
}

Future<bool> _refrescarSesionInterno() async {
  final refreshToken = await obtenerRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) return false;

  final endpoints = <String>[
    crearUrl(rutaRefresh),
    crearUrlVillarDo('/api/auth/refresh'),
    crearUrlVillarDo('/api/auth/refrescar'),
    crearUrlVillarDo('/api/auth/renovar-token'),
  ];

  for (final endpoint in endpoints) {
    try {
      final respuesta = await http
          .post(
            Uri.parse(endpoint),
            headers: crearCabeceras(json: true),
            body: jsonEncode({
              'refresh_token': refreshToken,
              'client_id': clienteVillarDo,
              'app_key': villarDoAppKey,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        continue;
      }

      final cuerpo = _decodificarCuerpo(respuesta);
      final datos = _extraerMapaDatos(cuerpo);
      final guardado = await _guardarSesionDesdeMapaRefresh(datos);
      if (guardado) return true;
    } catch (_) {
      continue;
    }
  }

  return false;
}

dynamic _decodificarCuerpo(http.Response respuesta) {
  try {
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  } catch (_) {
    return <String, dynamic>{'mensaje': respuesta.body};
  }
}

Map<String, dynamic> _extraerMapaDatos(dynamic cuerpo) {
  if (cuerpo is Map) {
    final mapa = Map<String, dynamic>.from(cuerpo);
    final datos = mapa['datos'] ?? mapa['data'];
    if (datos is Map) {
      return Map<String, dynamic>.from(datos);
    }
    return mapa;
  }
  return <String, dynamic>{};
}

Future<bool> _guardarSesionDesdeMapaRefresh(Map<String, dynamic> datos) async {
  final usuario = datos['usuario'];
  final usuarioMapa = usuario is Map ? Map<String, dynamic>.from(usuario) : <String, dynamic>{};

  final token = datos['access_token']?.toString() ??
      datos['token']?.toString() ??
      datos['jwt']?.toString();
  final nuevoRefresh = datos['refresh_token']?.toString() ??
      datos['refresh']?.toString() ??
      datos['nuevo_refresh_token']?.toString();
  final villarId = datos['villar_id']?.toString() ??
      datos['usuario_id']?.toString() ??
      usuarioMapa['villar_id']?.toString() ??
      usuarioMapa['id']?.toString() ??
      _extraerVillarIdDesdeJwtLocal(token);

  if (token == null || token.isEmpty) return false;

  await guardarToken(token);
  if (nuevoRefresh != null && nuevoRefresh.isNotEmpty) {
    await guardarRefreshToken(nuevoRefresh);
  }
  if (villarId != null && villarId.isNotEmpty) {
    await guardarVillarId(villarId);
  }
  return true;
}

String? _extraerVillarIdDesdeJwtLocal(String? token) {
  if (token == null || token.isEmpty) return null;
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

Map<String, dynamic> procesarRespuesta(http.Response respuesta) {
  final cuerpo = _decodificarCuerpo(respuesta);

  final mapa = cuerpo is Map
      ? Map<String, dynamic>.from(cuerpo)
      : <String, dynamic>{'datos': cuerpo};

  if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
    return mapa;
  }

  if (respuesta.statusCode == 401) {
    throw const SesionExpiradaException();
  }

  final detalle = mapa['detail'];
  if (detalle is Map && detalle['mensaje'] != null) {
    throw Exception(detalle['mensaje']);
  }
  if (detalle is String && detalle.isNotEmpty) {
    throw Exception(detalle);
  }
  if (mapa['error'] != null) {
    throw Exception(mapa['error']);
  }
  throw Exception(mapa['mensaje'] ?? 'Error al conectar con la API');
}

dynamic datosDe(Map<String, dynamic> respuesta) => respuesta['datos'];
