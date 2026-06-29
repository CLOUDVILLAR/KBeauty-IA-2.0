import '../config/config.dart';
import 'servicio_api.dart';

Future<List<Map<String, dynamic>>> obtenerMensajesChat() async {
  final respuesta = await enviarGet(rutaChatMensajes);
  final datos = datosDe(respuesta);
  if (datos is Map && datos['mensajes'] is List) {
    return (datos['mensajes'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
}

Future<Map<String, dynamic>> enviarMensajeChat(String mensaje) async {
  final respuesta = await enviarPost(rutaChatMensaje, {'mensaje': mensaje});
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}
