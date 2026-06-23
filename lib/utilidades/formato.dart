import 'package:intl/intl.dart';

String textoSeguro(dynamic valor, [String defecto = '']) {
  if (valor == null) return defecto;
  final texto = valor.toString().trim();
  return texto.isEmpty ? defecto : texto;
}

String fechaBonita(dynamic valor) {
  if (valor == null) return '';
  final fecha = DateTime.tryParse(valor.toString());
  if (fecha == null) return valor.toString();
  return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());
}

double numeroSeguro(dynamic valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> listaMapas(dynamic valor) {
  if (valor is List) {
    return valor.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  return [];
}

Map<String, dynamic> mapaSeguro(dynamic valor) {
  if (valor is Map) return Map<String, dynamic>.from(valor);
  return <String, dynamic>{};
}
