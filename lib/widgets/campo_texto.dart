import 'package:flutter/material.dart';

Widget campoTexto({
  required TextEditingController controlador,
  required String etiqueta,
  IconData? icono,
  bool oculto = false,
  TextInputType tipo = TextInputType.text,
}) {
  return TextField(
    controller: controlador,
    obscureText: oculto,
    keyboardType: tipo,
    decoration: InputDecoration(prefixIcon: icono == null ? null : Icon(icono), labelText: etiqueta),
  );
}
