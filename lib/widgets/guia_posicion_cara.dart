import 'package:flutter/material.dart';

import '../tema/tema_app.dart';
import 'silueta_cara.dart';

/// Muestra una guia visual de como posicionar la cara antes de abrir la
/// camara guiada (que dibuja esta misma silueta en tiempo real).
/// [indice]: 0 = frente, 1 = lado izquierdo, 2 = lado derecho.
/// Devuelve true si la persona presiono "Abrir camara".
Future<bool> mostrarGuiaPosicionCara(BuildContext context, int indice) async {
  final aceptado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoGuiaCara(indice: indice),
  );
  return aceptado == true;
}

class _DialogoGuiaCara extends StatelessWidget {
  const _DialogoGuiaCara({required this.indice});

  final int indice;

  static const titulos = ['Frente', 'Lado izquierdo', 'Lado derecho'];

  String get instruccion {
    switch (indice) {
      case 1:
        return 'Gira tu cabeza hacia la DERECHA para mostrar el lado izquierdo de tu rostro.';
      case 2:
        return 'Gira tu cabeza hacia la IZQUIERDA para mostrar el lado derecho de tu rostro.';
      default:
        return 'Mira de frente a la cámara y centra tu rostro dentro de la silueta.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Foto ${indice + 1} de 3: ${titulos[indice]}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 190,
                  height: 230,
                  child: CustomPaint(painter: PintorSiluetaCara(indice: indice, conMarco: false)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
              ),
              const SizedBox(height: 10),
              const Text(
                'Busca buena luz, retira lentes y despeja el rostro del cabello. '
                'Mantén el teléfono a la altura de los ojos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Abrir cámara'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
