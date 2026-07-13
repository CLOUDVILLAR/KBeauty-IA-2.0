import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../servicios/servicio_analisis.dart';
import '../servicios/servicio_api.dart';
import '../tema/tema_app.dart';
import 'pantalla_resultado_analisis.dart';

/// Splash animado que envia las 3 fotos y no se cierra hasta tener el
/// resultado. Si algo falla, reintenta automaticamente y muestra el detalle
/// abajo en letra pequena. Solo sale de la pantalla si la sesion expira
/// (devuelve el mensaje como String al hacer pop).
class PantallaAnalizando extends StatefulWidget {
  const PantallaAnalizando({
    super.key,
    required this.frente,
    required this.ladoIzquierdo,
    required this.ladoDerecho,
  });

  final File frente;
  final File ladoIzquierdo;
  final File ladoDerecho;

  @override
  State<PantallaAnalizando> createState() => _PantallaAnalizandoState();
}

class _PantallaAnalizandoState extends State<PantallaAnalizando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;
  Timer? _timerMensajes;
  int _indiceMensaje = 0;
  int _intento = 0;
  String _detalleError = '';

  static const _mensajes = [
    'La IA está estudiando tu rostro...',
    'Detectando manchas, textura y poros...',
    'Comparando tus tres tomas...',
    'Analizando cada zona de tu piel...',
    'Preparando tus recomendaciones...',
    'Ya casi está, un momento más...',
  ];

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _timerMensajes = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() => _indiceMensaje = (_indiceMensaje + 1) % _mensajes.length);
      }
    });

    _analizar();
  }

  @override
  void dispose() {
    _pulso.dispose();
    _timerMensajes?.cancel();
    super.dispose();
  }

  Future<void> _analizar() async {
    while (mounted) {
      _intento++;
      try {
        final resultado = await enviarTresFotosAnalisis(
          frente: widget.frente,
          ladoIzquierdo: widget.ladoIzquierdo,
          ladoDerecho: widget.ladoDerecho,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PantallaResultadoAnalisis(resultado: resultado),
          ),
        );
        return;
      } on SesionExpiradaException catch (error) {
        // Sin sesion no tiene sentido reintentar: se vuelve al login.
        if (mounted) Navigator.of(context).pop(error.mensaje);
        return;
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _detalleError = error.toString().replaceFirst('Exception: ', '');
        });
        await Future.delayed(const Duration(seconds: 6));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF5B60), KBeautyColors.rojo, Color(0xFF9E1B20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  // Logo pulsante con halo.
                  ScaleTransition(
                    scale: Tween<double>(begin: .92, end: 1.08).animate(
                      CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                    ),
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(.45),
                              blurRadius: 60,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural_rounded,
                          color: KBeautyColors.rojo,
                          size: 74,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  const Text(
                    'Analizando tu piel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mensajes rotativos con fundido.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      _mensajes[_indiceMensaje],
                      key: ValueKey(_indiceMensaje),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Center(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.5,
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  // Estado de reintentos, discreto y abajo.
                  if (_detalleError.isNotEmpty) ...[
                    Text(
                      'Intentando de nuevo... (intento $_intento)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detalleError,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'No cierres la app. Esto puede tardar un poco.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
