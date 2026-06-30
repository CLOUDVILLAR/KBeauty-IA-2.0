import 'dart:io';

import '../config/config.dart';
import 'servicio_api.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> enviarFotoAnalisis(File imagen) async {
  final respuesta = await enviarImagen(rutaNuevoAnalisis, imagen);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<Map<String, dynamic>> enviarTresFotosAnalisis({
  required File frente,
  required File ladoIzquierdo,
  required File ladoDerecho,
}) async {
  final respuesta = await enviarTresImagenes(
    rutaNuevoAnalisis,
    frente: frente,
    ladoIzquierdo: ladoIzquierdo,
    ladoDerecho: ladoDerecho,
  );
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<List<Map<String, dynamic>>> obtenerHistorialAnalisis({int limite = 20}) async {
  final respuesta = await enviarGet('$rutaHistorialAnalisis?limite=$limite');
  final datos = datosDe(respuesta);
  if (datos is List) return datos.map((e) => Map<String, dynamic>.from(e)).toList();
  return [];
}

Future<Map<String, dynamic>> obtenerDetalleAnalisis(String id) async {
  final respuesta = await enviarGet('/analisis/$id');
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}


bool esAnalisisPresencial(Map<String, dynamic> item) {
  final tipo = (item['tipo_analisis'] ?? item['tipo'] ?? item['origen'] ?? '').toString().toLowerCase();
  final vista = (item['vista_destino'] ?? '').toString().toLowerCase();
  final etiqueta = (item['etiqueta'] ?? '').toString().toLowerCase();
  final pdfDisponible = item['pdf_disponible'] == true;

  return tipo == 'presencial_pdf' ||
      tipo == 'presencial' ||
      vista == 'pdf' ||
      etiqueta == 'presencial' ||
      pdfDisponible;
}

String urlPdfAnalisisPresencial(String id) {
  return crearUrl('/analisis-presencial/$id/pdf');
}

Future<Map<String, String>> obtenerCabecerasPdfPresencial() async {
  final token = await obtenerToken();
  return crearCabeceras(json: false, token: token);
}

Future<File> descargarPdfAnalisisPresencial(String id) async {
  if (id.trim().isEmpty) {
    throw Exception('No se encontro el ID del analisis presencial.');
  }

  Future<http.Response> pedirPdf(String? token) async {
    final cabeceras = crearCabeceras(json: false, token: token);
    cabeceras['Accept'] = 'application/pdf';

    return http
        .get(
          Uri.parse(urlPdfAnalisisPresencial(id)),
          headers: cabeceras,
        )
        .timeout(tiempoEsperaApi);
  }

  var token = await obtenerToken();
  var respuesta = await pedirPdf(token);

  if (respuesta.statusCode == 401) {
    final refrescado = await refrescarSesionSiHaceFalta();

    if (!refrescado) {
      throw Exception('Sesion expirada. Inicia sesion nuevamente.');
    }

    token = await obtenerToken();
    respuesta = await pedirPdf(token);
  }

  if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
    final cuerpo = respuesta.body.trim();
    throw Exception(
      'La API no devolvio el PDF. Estado ${respuesta.statusCode}${cuerpo.isEmpty ? '' : ': $cuerpo'}',
    );
  }

  final bytes = respuesta.bodyBytes;

  final esPdf = bytes.length >= 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;

  if (!esPdf) {
    String muestra = '';
    try {
      muestra = utf8.decode(bytes).trim();
    } catch (_) {
      muestra = respuesta.body.trim();
    }

    throw Exception(
      'La respuesta no es un PDF valido.${muestra.isEmpty ? '' : ' Respuesta: $muestra'}',
    );
  }

  final nombreSeguro = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final archivo = File(
    '${Directory.systemTemp.path}/kbeauty_presencial_$nombreSeguro.pdf',
  );

  await archivo.writeAsBytes(bytes, flush: true);
  return archivo;
}