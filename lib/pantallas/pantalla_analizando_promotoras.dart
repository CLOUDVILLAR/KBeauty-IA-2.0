import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servicios/servicio_promotoras.dart';
import '../tema/tema_app.dart';
import 'pantalla_inicio_promotoras.dart';
import 'pantalla_resultado_analisis.dart';

/// Splash que envia las 3 fotos, guarda el analisis y muestra el resultado
/// completo de una sola vez. A diferencia de PantallaAnalizando, no hay
/// sesion que pueda expirar: cualquier error (de la foto o del guardado) se
/// reintenta el proceso completo hasta que funcione.
class PantallaAnalizandoPromotoras extends StatefulWidget {
  const PantallaAnalizandoPromotoras({
    super.key,
    required this.frente,
    required this.ladoIzquierdo,
    required this.ladoDerecho,
    required this.clienteNombre,
    required this.clienteApellido,
    required this.clienteTelefono,
    this.rutinaElegida,
  });

  final File frente;
  final File ladoIzquierdo;
  final File ladoDerecho;
  final String clienteNombre;
  final String clienteApellido;
  final String clienteTelefono;
  final String? rutinaElegida;

  @override
  State<PantallaAnalizandoPromotoras> createState() => _PantallaAnalizandoPromotorasState();
}

class _PantallaAnalizandoPromotorasState extends State<PantallaAnalizandoPromotoras>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;
  int _intento = 0;
  String _detalleError = '';

  @override
  void initState() {
    super.initState();
    // Splash de carga: se ve en pantalla completa, sin barra de estado ni
    // barra de navegacion del sistema encima.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _analizar();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _analizar() async {
    while (mounted) {
      _intento++;
      try {
        final resultadoIa = await analizarFotosPromotoras(
          frente: widget.frente,
          ladoIzquierdo: widget.ladoIzquierdo,
          ladoDerecho: widget.ladoDerecho,
        );
        if (!mounted) return;

        final resultado = await guardarAnalisisPromotora(
          clienteNombre: widget.clienteNombre,
          clienteApellido: widget.clienteApellido,
          clienteTelefono: widget.clienteTelefono,
          resultadoIa: resultadoIa,
          rutinaNombre: widget.rutinaElegida,
        );
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PantallaResultadoAnalisis(
              resultado: resultado,
              clienteNombre: widget.clienteNombre,
              clienteTelefono: widget.clienteTelefono,
              onVolverInicio: (contextResultado) => Navigator.of(contextResultado).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PantallaInicioPromotoras()),
                (ruta) => false,
              ),
            ),
          ),
          (ruta) => false,
        );
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: .92, end: 1.08).animate(
                      CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      width: 140,
                      height: 140,
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
                        size: 70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Analizando la piel',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 24),
                  if (_detalleError.isNotEmpty) ...[
                    Text(
                      'Intentando de nuevo... (intento $_intento)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detalleError,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
