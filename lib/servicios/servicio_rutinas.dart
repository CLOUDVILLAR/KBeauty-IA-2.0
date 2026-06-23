import '../config/config.dart';
import 'servicio_api.dart';

Future<Map<String, dynamic>> obtenerRutinaRecomendada() async {
  final respuesta = await enviarGet(rutaRutinaRecomendada);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}
