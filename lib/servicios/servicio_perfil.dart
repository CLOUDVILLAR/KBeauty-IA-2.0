import '../config/config.dart';
import 'servicio_api.dart';

Future<Map<String, dynamic>> obtenerEstadoPerfil() async {
  final respuesta = await enviarGet(rutaEstadoPerfil);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<Map<String, dynamic>> obtenerOpcionesPerfil() async {
  final respuesta = await enviarGet(rutaOpcionesPerfil, requiereToken: false);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<Map<String, dynamic>> guardarFormularioPiel(Map<String, dynamic> datos) async {
  final respuesta = await enviarPost(rutaFormularioPerfil, datos);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}

Future<Map<String, dynamic>> obtenerFormularioPiel() async {
  final respuesta = await enviarGet(rutaFormularioPerfil);
  return Map<String, dynamic>.from(datosDe(respuesta) ?? {});
}
