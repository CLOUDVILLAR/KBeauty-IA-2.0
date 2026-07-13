import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Muestra una guia visual de como posicionar la cara antes de abrir la
/// camara nativa (sobre la camara del sistema no se puede dibujar).
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
        return 'Mira de frente a la cámara y centra tu rostro dentro del óvalo.';
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
                  child: CustomPaint(painter: _PintorGuiaCara(indice: indice)),
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

class _PintorGuiaCara extends CustomPainter {
  _PintorGuiaCara({required this.indice});

  final int indice;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);

    final fondo = Paint()..color = KBeautyColors.rojo.withOpacity(.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      fondo,
    );

    final trazoOvalo = Paint()
      ..color = KBeautyColors.rojo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Ovalo de la cara: de frente centrado; de lado, desplazado y mas angosto
    // para sugerir el perfil.
    final esPerfil = indice != 0;
    final anchoOvalo = esPerfil ? size.width * .46 : size.width * .62;
    final altoOvalo = size.height * .66;
    final desplazamiento = indice == 1
        ? size.width * .08
        : indice == 2
            ? -size.width * .08
            : 0.0;
    final rectOvalo = Rect.fromCenter(
      center: centro.translate(desplazamiento, 0),
      width: anchoOvalo,
      height: altoOvalo,
    );
    _dibujarOvaloPunteado(canvas, rectOvalo, trazoOvalo);

    final trazoGuia = Paint()
      ..color = KBeautyColors.rojo.withOpacity(.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Linea de los ojos.
    final alturaOjos = rectOvalo.top + rectOvalo.height * .42;
    _dibujarLineaPunteada(
      canvas,
      Offset(rectOvalo.left + 10, alturaOjos),
      Offset(rectOvalo.right - 10, alturaOjos),
      trazoGuia,
    );

    if (!esPerfil) {
      // Linea central vertical solo en la foto de frente.
      _dibujarLineaPunteada(
        canvas,
        Offset(rectOvalo.center.dx, rectOvalo.top + 8),
        Offset(rectOvalo.center.dx, rectOvalo.bottom - 8),
        trazoGuia,
      );
    } else {
      // Flecha indicando hacia donde girar la cabeza.
      _dibujarFlechaGiro(canvas, size, haciaDerecha: indice == 1);
    }
  }

  void _dibujarOvaloPunteado(Canvas canvas, Rect rect, Paint pintura) {
    final camino = Path()..addOval(rect);
    for (final metrica in camino.computeMetrics()) {
      const largoSegmento = 9.0;
      const largoEspacio = 7.0;
      var distancia = 0.0;
      while (distancia < metrica.length) {
        final fin = math.min(distancia + largoSegmento, metrica.length);
        canvas.drawPath(metrica.extractPath(distancia, fin), pintura);
        distancia = fin + largoEspacio;
      }
    }
  }

  void _dibujarLineaPunteada(Canvas canvas, Offset inicio, Offset fin, Paint pintura) {
    const largoSegmento = 6.0;
    const largoEspacio = 5.0;
    final total = (fin - inicio).distance;
    final direccion = (fin - inicio) / total;
    var distancia = 0.0;
    while (distancia < total) {
      final hasta = math.min(distancia + largoSegmento, total);
      canvas.drawLine(inicio + direccion * distancia, inicio + direccion * hasta, pintura);
      distancia = hasta + largoEspacio;
    }
  }

  void _dibujarFlechaGiro(Canvas canvas, Size size, {required bool haciaDerecha}) {
    final pintura = Paint()
      ..color = KBeautyColors.rojo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centroArco = Offset(size.width / 2, size.height * .88);
    final radio = size.width * .28;
    final rect = Rect.fromCircle(center: centroArco, radius: radio);

    // Arco inferior con punta de flecha en el extremo del giro.
    final inicio = haciaDerecha ? math.pi * .75 : math.pi * .05;
    const barrido = math.pi * .2;
    canvas.drawArc(rect, inicio, barrido, false, pintura);

    final anguloPunta = haciaDerecha ? inicio : inicio + barrido;
    final punta = centroArco + Offset(math.cos(anguloPunta), math.sin(anguloPunta)) * radio;
    final relleno = Paint()..color = KBeautyColors.rojo;
    final caminoPunta = Path();
    const tam = 7.0;
    if (haciaDerecha) {
      caminoPunta
        ..moveTo(punta.dx - tam, punta.dy - tam)
        ..lineTo(punta.dx + tam, punta.dy)
        ..lineTo(punta.dx - tam, punta.dy + tam);
    } else {
      caminoPunta
        ..moveTo(punta.dx + tam, punta.dy - tam)
        ..lineTo(punta.dx - tam, punta.dy)
        ..lineTo(punta.dx + tam, punta.dy + tam);
    }
    caminoPunta.close();
    canvas.drawPath(caminoPunta, relleno);
  }

  @override
  bool shouldRepaint(covariant _PintorGuiaCara anterior) => anterior.indice != indice;
}
