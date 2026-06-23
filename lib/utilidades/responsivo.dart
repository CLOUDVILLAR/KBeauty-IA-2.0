import 'package:flutter/material.dart';

double anchoContenido(BuildContext context) {
  final ancho = MediaQuery.sizeOf(context).width;
  if (ancho >= 900) return 620;
  if (ancho >= 600) return 540;
  return ancho;
}

EdgeInsets margenPantalla(BuildContext context) {
  final ancho = MediaQuery.sizeOf(context).width;
  final horizontal = ancho >= 600 ? 32.0 : 18.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
}

Widget centrarContenido(BuildContext context, Widget hijo) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: anchoContenido(context)),
      child: hijo,
    ),
  );
}

bool pantallaPequena(BuildContext context) => MediaQuery.sizeOf(context).width < 380;
