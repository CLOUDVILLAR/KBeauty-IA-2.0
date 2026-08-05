import 'dart:io';

import '../config/config.dart';
import 'servicio_api_promotoras.dart';

Future<List<Map<String, dynamic>>> obtenerRutinasPromotoras() async {
  final respuesta = await enviarGetPromotoras(rutaPromotorasRutinas);
  final datos = respuesta['datos'];
  if (datos is List) {
    return datos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return [];
}

Future<Map<String, dynamic>> analizarFotosPromotoras({
  required File frente,
  required File ladoIzquierdo,
  required File ladoDerecho,
}) async {
  final respuesta = await enviarTresImagenesPromotoras(
    rutaPromotorasAnalisis,
    frente: frente,
    ladoIzquierdo: ladoIzquierdo,
    ladoDerecho: ladoDerecho,
  );
  final datos = Map<String, dynamic>.from(respuesta['datos'] ?? {});
  return Map<String, dynamic>.from(datos['resultado_ia'] ?? {});
}

/// [rutinaNombre] es el nombre exacto de la rutina (del JSON) que confirma
/// la promotora, o null si eligio "No lo se" (en ese caso el backend usa el
/// tipo de piel y la condicion que estimo la IA a partir de las fotos).
Future<Map<String, dynamic>> guardarAnalisisPromotora({
  required String clienteNombre,
  required String clienteTelefono,
  required Map<String, dynamic> resultadoIa,
  String clienteApellido = '',
  String? rutinaNombre,
}) async {
  final cuerpo = <String, dynamic>{
    'cliente_nombre': clienteNombre,
    'cliente_apellido': clienteApellido,
    'cliente_telefono': clienteTelefono,
    'resultado_ia': resultadoIa,
  };
  if (rutinaNombre != null) {
    cuerpo['rutina_nombre'] = rutinaNombre;
  }

  final respuesta = await enviarPostPromotoras(rutaPromotorasGuardar, cuerpo);
  return Map<String, dynamic>.from(respuesta['datos'] ?? {});
}

Future<List<Map<String, dynamic>>> obtenerHistorialPromotoras({int limite = 50}) async {
  final respuesta = await enviarGetPromotoras('$rutaPromotorasHistorial?limite=$limite');
  final datos = respuesta['datos'];
  if (datos is List) {
    return datos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return [];
}

Future<Map<String, dynamic>> obtenerDetalleHistorialPromotora(String analisisId) async {
  final respuesta = await enviarGetPromotoras('$rutaPromotorasHistorial/$analisisId');
  return Map<String, dynamic>.from(respuesta['datos'] ?? {});
}
