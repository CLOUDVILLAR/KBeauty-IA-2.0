import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

Widget tarjetaBase({required Widget hijo, EdgeInsets? margen, EdgeInsets? relleno}) {
  return Container(
    margin: margen ?? const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: KBeautyColors.borde),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Padding(
      padding: relleno ?? const EdgeInsets.all(20),
      child: hijo,
    ),
  );
}

Widget tarjetaSuave({required Widget hijo, EdgeInsets? margen, EdgeInsets? relleno}) {
  return Container(
    margin: margen ?? const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: KBeautyColors.rosaMuySuave,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: KBeautyColors.borde),
    ),
    child: Padding(
      padding: relleno ?? const EdgeInsets.all(18),
      child: hijo,
    ),
  );
}

Widget tarjetaGradiente({required Widget hijo, EdgeInsets? margen, EdgeInsets? relleno}) {
  return Container(
    margin: margen ?? const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDC1015), Color(0xFFFF6B6F)],
      ),
      boxShadow: [
        BoxShadow(
          color: KBeautyColors.rojo.withOpacity(.22),
          blurRadius: 30,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    child: Padding(
      padding: relleno ?? const EdgeInsets.all(22),
      child: hijo,
    ),
  );
}

Widget tituloSeccion(String texto, {IconData? icono, String? subtitulo}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icono != null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: KBeautyColors.rojoSuave,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, size: 19, color: KBeautyColors.rojo),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: KBeautyColors.texto),
              ),
            ),
          ],
        ),
        if (subtitulo != null && subtitulo.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitulo, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600)),
        ],
      ],
    ),
  );
}

Widget chipSuave(String texto, {IconData? icono, Color color = KBeautyColors.rojo}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(.13)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    ),
  );
}
