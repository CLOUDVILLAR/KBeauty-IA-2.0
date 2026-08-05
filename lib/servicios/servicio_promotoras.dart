import 'dart:io';

import '../config/config.dart';
import 'servicio_api_promotoras.dart';

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

/// [tipoPielSeleccionado] es el tipo de piel que confirma la promotora, o
/// null si eligio "No lo se" (en ese caso el backend usa el estimado por la
/// IA a partir de las mismas fotos). La condicion siempre la decide el
/// analisis de fotos, nunca se elige a mano.
Future<Map<String, dynamic>> guardarAnalisisPromotora({
  required String clienteNombre,
  required String clienteTelefono,
  required Map<String, dynamic> resultadoIa,
  String clienteApellido = '',
  String? tipoPielSeleccionado,
}) async {
  final cuerpo = <String, dynamic>{
    'cliente_nombre': clienteNombre,
    'cliente_apellido': clienteApellido,
    'cliente_telefono': clienteTelefono,
    'resultado_ia': resultadoIa,
  };
  if (tipoPielSeleccionado != null) {
    cuerpo['tipo_piel_seleccionado'] = tipoPielSeleccionado;
  }

  final respuesta = await enviarPostPromotoras(rutaPromotorasGuardar, cuerpo);
  return Map<String, dynamic>.from(respuesta['datos'] ?? {});
}
