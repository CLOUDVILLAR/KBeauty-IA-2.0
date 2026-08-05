import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/config.dart';
import 'servicio_api.dart';

/// Capa HTTP separada de servicio_api.dart: la tablet de promotoras no tiene
/// sesion de usuario ni token de Villar.do, se autentica con una clave fija.
Map<String, String> _cabecerasPromotoras({bool json = true}) {
  final cabeceras = <String, String>{'Accept': 'application/json'};
  if (json) cabeceras['Content-Type'] = 'application/json';
  if (promotorasAppKey.isNotEmpty) {
    cabeceras['X-Promotoras-Key'] = promotorasAppKey;
  }
  return cabeceras;
}

Map<String, dynamic> _procesarRespuestaPromotoras(http.Response respuesta) {
  try {
    return procesarRespuesta(respuesta);
  } on SesionExpiradaException {
    throw Exception('Clave de promotoras invalida o no configurada. Contacta a soporte.');
  }
}

Future<Map<String, dynamic>> enviarGetPromotoras(String ruta) async {
  final respuesta = await http
      .get(Uri.parse(crearUrl(ruta)), headers: _cabecerasPromotoras())
      .timeout(tiempoEsperaApi);
  return _procesarRespuestaPromotoras(respuesta);
}

Future<Map<String, dynamic>> enviarPostPromotoras(
  String ruta,
  Map<String, dynamic> datos,
) async {
  final respuesta = await http
      .post(
        Uri.parse(crearUrl(ruta)),
        headers: _cabecerasPromotoras(),
        body: jsonEncode(datos),
      )
      .timeout(tiempoEsperaApi);
  return _procesarRespuestaPromotoras(respuesta);
}

Future<Map<String, dynamic>> enviarTresImagenesPromotoras(
  String ruta, {
  required File frente,
  required File ladoIzquierdo,
  required File ladoDerecho,
}) async {
  final solicitud = http.MultipartRequest('POST', Uri.parse(crearUrl(ruta)));
  solicitud.headers.addAll(_cabecerasPromotoras(json: false));

  solicitud.files.add(await http.MultipartFile.fromPath('frente', frente.path));
  solicitud.files.add(await http.MultipartFile.fromPath('lado_izquierdo', ladoIzquierdo.path));
  solicitud.files.add(await http.MultipartFile.fromPath('lado_derecho', ladoDerecho.path));

  final enviada = await solicitud.send().timeout(tiempoEsperaSubida);
  final respuesta = await http.Response.fromStream(enviada);
  return _procesarRespuestaPromotoras(respuesta);
}
