import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

Widget botonPrincipal({
  required String texto,
  required VoidCallback? alPresionar,
  IconData? icono,
  bool cargando = false,
}) {
  final deshabilitado = cargando || alPresionar == null;
  final contenido = cargando
      ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icono != null) ...[Icon(icono, size: 20), const SizedBox(width: 8)],
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        );

  return SizedBox(
    width: double.infinity,
    height: 56,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: deshabilitado
            ? null
            : const LinearGradient(
                colors: [KBeautyColors.rojo, Color(0xFFFF5B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: deshabilitado
            ? []
            : [
                BoxShadow(
                  color: KBeautyColors.rojo.withOpacity(.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: FilledButton(
        onPressed: deshabilitado ? null : alPresionar,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: const Color(0xFFE9D8DA),
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: contenido,
      ),
    ),
  );
}
