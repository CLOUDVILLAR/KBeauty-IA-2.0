import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/config.dart';
import 'servicio_api.dart';

Future<Map<String, dynamic>> importarAnalisisExternoPdf(File pdf) async {
  Future<http.Response> ejecutarPeticion(String? token) async {
    final solicitud = http.MultipartRequest('POST', Uri.parse(crearUrl('/analisis-externos/importar')));

    solicitud.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      solicitud.headers['Authorization'] = 'Bearer $token';
    }
    if (villarDoAppKey.isNotEmpty) {
      solicitud.headers['X-Villar-App-Key'] = villarDoAppKey;
      solicitud.headers['X-Villar-Client-Id'] = clienteVillarDo;
      solicitud.headers['X-Villar-Api-Key'] = villarDoAppKey;
    }

    solicitud.files.add(await http.MultipartFile.fromPath('pdf', pdf.path));
    final enviada = await solicitud.send().timeout(tiempoEsperaApi);
    return http.Response.fromStream(enviada);
  }

  var token = await obtenerToken();
  var respuesta = await ejecutarPeticion(token);

  if (respuesta.statusCode == 401) {
    final refrescado = await refrescarSesionSiHaceFalta();
    if (!refrescado) {
      await borrarSesionLocalYVerificar();
      throw const SesionExpiradaException();
    }
    token = await obtenerToken();
    respuesta = await ejecutarPeticion(token);
  }

  return procesarRespuesta(respuesta);
}

Future<List<Map<String, dynamic>>> obtenerHistorialAnalisisExterno({int limite = 20}) async {
  final respuesta = await enviarGet('/analisis-externos/historial?limite=$limite');
  final datos = datosDe(respuesta);
  if (datos is List) {
    return datos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return <Map<String, dynamic>>[];
}

Future<Map<String, dynamic>> obtenerDetalleAnalisisExterno(String id) async {
  final respuesta = await enviarGet('/analisis-externos/$id');
  final datos = datosDe(respuesta);
  if (datos is Map) return Map<String, dynamic>.from(datos);
  return <String, dynamic>{};
}
