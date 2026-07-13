import 'package:flutter/material.dart';

/// Dibuja la silueta guia de la cara (estilo plantilla de foto de pasaporte):
/// marco con esquinas + contorno de cabeza. Se usa tanto en el dialogo de
/// guia como superpuesta en la camara en tiempo real.
/// [indice]: 0 = frente, 1 = lado izquierdo, 2 = lado derecho.
class PintorSiluetaCara extends CustomPainter {
  PintorSiluetaCara({
    required this.indice,
    this.color = const Color(0xFFE53935),
    this.grosor = 3,
    this.conMarco = true,
  });

  final int indice;
  final Color color;
  final double grosor;
  final bool conMarco;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    if (conMarco) _dibujarEsquinas(canvas, size, trazo);

    // Area interna donde vive la silueta.
    final area = Rect.fromLTWH(
      size.width * .10,
      size.height * .08,
      size.width * .80,
      size.height * .84,
    );

    // Para el lado derecho se dibuja el perfil espejado.
    if (indice == 2) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    if (indice == 0) {
      _dibujarFrente(canvas, area, trazo);
    } else {
      _dibujarPerfil(canvas, area, trazo);
    }

    if (indice == 2) canvas.restore();
  }

  Offset _p(Rect r, double x, double y) =>
      Offset(r.left + x * r.width, r.top + y * r.height);

  void _dibujarEsquinas(Canvas canvas, Size size, Paint trazo) {
    final largo = size.shortestSide * .08;
    const margen = 6.0;
    final w = size.width;
    final h = size.height;

    final camino = Path()
      // superior izquierda
      ..moveTo(margen, margen + largo)
      ..lineTo(margen, margen)
      ..lineTo(margen + largo, margen)
      // superior derecha
      ..moveTo(w - margen - largo, margen)
      ..lineTo(w - margen, margen)
      ..lineTo(w - margen, margen + largo)
      // inferior derecha
      ..moveTo(w - margen, h - margen - largo)
      ..lineTo(w - margen, h - margen)
      ..lineTo(w - margen - largo, h - margen)
      // inferior izquierda
      ..moveTo(margen + largo, h - margen)
      ..lineTo(margen, h - margen)
      ..lineTo(margen, h - margen - largo);

    canvas.drawPath(camino, trazo);
  }

  void _dibujarFrente(Canvas canvas, Rect r, Paint trazo) {
    final camino = Path()
      // Craneo: desde arriba de la oreja izquierda hasta arriba de la derecha.
      ..moveTo(_p(r, .225, .42).dx, _p(r, .225, .42).dy)
      ..cubicTo(_p(r, .19, .16).dx, _p(r, .19, .16).dy, _p(r, .34, .04).dx,
          _p(r, .34, .04).dy, _p(r, .50, .04).dx, _p(r, .50, .04).dy)
      ..cubicTo(_p(r, .66, .04).dx, _p(r, .66, .04).dy, _p(r, .81, .16).dx,
          _p(r, .81, .16).dy, _p(r, .775, .42).dx, _p(r, .775, .42).dy)
      // Oreja derecha.
      ..cubicTo(_p(r, .815, .395).dx, _p(r, .815, .395).dy, _p(r, .835, .43).dx,
          _p(r, .835, .43).dy, _p(r, .825, .47).dx, _p(r, .825, .47).dy)
      ..cubicTo(_p(r, .81, .53).dx, _p(r, .81, .53).dy, _p(r, .78, .565).dx,
          _p(r, .78, .565).dy, _p(r, .755, .55).dx, _p(r, .755, .55).dy)
      // Mejilla derecha, menton y mejilla izquierda.
      ..cubicTo(_p(r, .72, .68).dx, _p(r, .72, .68).dy, _p(r, .63, .78).dx,
          _p(r, .63, .78).dy, _p(r, .50, .78).dx, _p(r, .50, .78).dy)
      ..cubicTo(_p(r, .37, .78).dx, _p(r, .37, .78).dy, _p(r, .28, .68).dx,
          _p(r, .28, .68).dy, _p(r, .245, .55).dx, _p(r, .245, .55).dy)
      // Oreja izquierda.
      ..cubicTo(_p(r, .22, .565).dx, _p(r, .22, .565).dy, _p(r, .19, .53).dx,
          _p(r, .19, .53).dy, _p(r, .175, .47).dx, _p(r, .175, .47).dy)
      ..cubicTo(_p(r, .165, .43).dx, _p(r, .165, .43).dy, _p(r, .185, .395).dx,
          _p(r, .185, .395).dy, _p(r, .225, .42).dx, _p(r, .225, .42).dy)
      // Cuello y hombros.
      ..moveTo(_p(r, .345, .735).dx, _p(r, .345, .735).dy)
      ..cubicTo(_p(r, .35, .84).dx, _p(r, .35, .84).dy, _p(r, .28, .92).dx,
          _p(r, .28, .92).dy, _p(r, .03, 1.0).dx, _p(r, .03, 1.0).dy)
      ..moveTo(_p(r, .655, .735).dx, _p(r, .655, .735).dy)
      ..cubicTo(_p(r, .65, .84).dx, _p(r, .65, .84).dy, _p(r, .72, .92).dx,
          _p(r, .72, .92).dy, _p(r, .97, 1.0).dx, _p(r, .97, 1.0).dy);

    canvas.drawPath(camino, trazo);
  }

  // Perfil mirando hacia la derecha (para el lado izquierdo del rostro; el
  // derecho se espeja desde paint()).
  void _dibujarPerfil(Canvas canvas, Rect r, Paint trazo) {
    final camino = Path()
      // Craneo y parte trasera de la cabeza.
      ..moveTo(_p(r, .58, .03).dx, _p(r, .58, .03).dy)
      ..cubicTo(_p(r, .30, .02).dx, _p(r, .30, .02).dy, _p(r, .10, .18).dx,
          _p(r, .10, .18).dy, _p(r, .12, .40).dx, _p(r, .12, .40).dy)
      ..cubicTo(_p(r, .13, .54).dx, _p(r, .13, .54).dy, _p(r, .20, .62).dx,
          _p(r, .20, .62).dy, _p(r, .24, .70).dx, _p(r, .24, .70).dy)
      // Cuello trasero y hombro.
      ..cubicTo(_p(r, .27, .80).dx, _p(r, .27, .80).dy, _p(r, .20, .90).dx,
          _p(r, .20, .90).dy, _p(r, .02, 1.0).dx, _p(r, .02, 1.0).dy)
      // Frente y cara.
      ..moveTo(_p(r, .58, .03).dx, _p(r, .58, .03).dy)
      ..cubicTo(_p(r, .76, .06).dx, _p(r, .76, .06).dy, _p(r, .86, .17).dx,
          _p(r, .86, .17).dy, _p(r, .86, .30).dx, _p(r, .86, .30).dy)
      // Frente hasta el puente de la nariz.
      ..cubicTo(_p(r, .86, .38).dx, _p(r, .86, .38).dy, _p(r, .835, .43).dx,
          _p(r, .835, .43).dy, _p(r, .85, .465).dx, _p(r, .85, .465).dy)
      // Nariz.
      ..cubicTo(_p(r, .91, .52).dx, _p(r, .91, .52).dy, _p(r, .925, .545).dx,
          _p(r, .925, .545).dy, _p(r, .885, .555).dx, _p(r, .885, .555).dy)
      // Labio superior e inferior.
      ..cubicTo(_p(r, .855, .565).dx, _p(r, .855, .565).dy, _p(r, .88, .585).dx,
          _p(r, .88, .585).dy, _p(r, .885, .60).dx, _p(r, .885, .60).dy)
      ..cubicTo(_p(r, .89, .625).dx, _p(r, .89, .625).dy, _p(r, .855, .63).dx,
          _p(r, .855, .63).dy, _p(r, .855, .645).dx, _p(r, .855, .645).dy)
      // Menton y mandibula.
      ..cubicTo(_p(r, .86, .68).dx, _p(r, .86, .68).dy, _p(r, .83, .715).dx,
          _p(r, .83, .715).dy, _p(r, .77, .735).dx, _p(r, .77, .735).dy)
      ..cubicTo(_p(r, .68, .765).dx, _p(r, .68, .765).dy, _p(r, .62, .77).dx,
          _p(r, .62, .77).dy, _p(r, .58, .765).dx, _p(r, .58, .765).dy)
      // Cuello delantero.
      ..cubicTo(_p(r, .565, .84).dx, _p(r, .565, .84).dy, _p(r, .565, .92).dx,
          _p(r, .565, .92).dy, _p(r, .60, 1.0).dx, _p(r, .60, 1.0).dy);

    canvas.drawPath(camino, trazo);
  }

  @override
  bool shouldRepaint(covariant PintorSiluetaCara anterior) =>
      anterior.indice != indice ||
      anterior.color != color ||
      anterior.grosor != grosor ||
      anterior.conMarco != conMarco;
}
