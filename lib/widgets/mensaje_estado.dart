import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

Widget cargandoCentro([String texto = 'Cargando...']) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 25, offset: const Offset(0, 12)),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

Widget mensajeError(String mensaje, {VoidCallback? alReintentar}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: KBeautyColors.borde),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: KBeautyColors.rojoSuave, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.error_outline, size: 34, color: KBeautyColors.rojo),
            ),
            const SizedBox(height: 14),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (alReintentar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}
