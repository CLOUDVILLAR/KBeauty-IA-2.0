import 'package:flutter/material.dart';

Widget selectorOpcion({
  required String etiqueta,
  required String? valor,
  required List<String> opciones,
  required ValueChanged<String?> alCambiar,
}) {
  final opcionesLimpias = opciones.where((opcion) => opcion.trim().isNotEmpty).toSet().toList();
  return DropdownButtonFormField<String>(
    value: opcionesLimpias.contains(valor) ? valor : null,
    items: opcionesLimpias.map((opcion) => DropdownMenuItem(value: opcion, child: Text(opcion))).toList(),
    onChanged: alCambiar,
    decoration: InputDecoration(labelText: etiqueta),
  );
}
