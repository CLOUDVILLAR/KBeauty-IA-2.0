import 'dart:io';

import '../config/config.dart';
import 'servicio_api.dart';

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
