import 'package:flutter/material.dart';

import '../utilidades/formato.dart';
import 'tarjeta_base.dart';

Widget tarjetaZona(String nombre, Map<String, dynamic> zona) {
  return tarjetaBase(
    hijo: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(textoSeguro(zona['resumen'], 'Sin resumen disponible.')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chipPuntaje('Poros', zona['poros']),
            chipPuntaje('Manchas', zona['manchas']),
            chipPuntaje('Arrugas', zona['arrugas']),
            chipPuntaje('Rojeces', zona['rojeces']),
            chipPuntaje('Acné', zona['acne']),
          ],
        ),
      ],
    ),
  );
}

Widget chipPuntaje(String etiqueta, dynamic valor) {
  final numero = numeroSeguro(valor);
  return Chip(label: Text('$etiqueta ${numero.toStringAsFixed(0)}'));
}
