import '../config/config.dart';
import 'servicio_api.dart';

Future<Map<String, dynamic>> obtenerResumenEvolucion() async {
  final respuesta = await enviarGet(rutaEvolucionResumen);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<List<Map<String, dynamic>>> obtenerHistorialEvolucion({int limite = 20}) async {
  final respuesta = await enviarGet('$rutaEvolucionHistorial?limite=$limite');
  final datos = datosDe(respuesta);
  if (datos is List) return datos.map((e) => Map<String, dynamic>.from(e)).toList();
  return [];
}
