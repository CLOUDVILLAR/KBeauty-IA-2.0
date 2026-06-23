import 'package:flutter/material.dart';

import '../servicios/servicio_api.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_login.dart';

class PantallaCerrandoSesion extends StatefulWidget {
  const PantallaCerrandoSesion({super.key});

  @override
  State<PantallaCerrandoSesion> createState() => _PantallaCerrandoSesionState();
}

class _PantallaCerrandoSesionState extends State<PantallaCerrandoSesion> {
  @override
  void initState() {
    super.initState();
    _cerrarSesion();
  }

  Future<void> _cerrarSesion() async {
    final inicio = DateTime.now();

    try {
      await cerrarSesionLocalYServidor();
      await borrarSesionLocalYVerificar();
      await bloquearCallbacksTemporalmente(segundos: 30);
    } catch (_) {
      // Si algo falla, igualmente dejamos la sesion local limpia.
      await bloquearCallbacksTemporalmente(segundos: 30);
      await borrarSesionLocalYVerificar();
      await marcarCierreSesionEnCurso(false);
    }

    final transcurrido = DateTime.now().difference(inicio);
    const minimoVisible = Duration(milliseconds: 1500);
    if (transcurrido < minimoVisible) {
      await Future.delayed(minimoVisible - transcurrido);
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 58,
                  color: Color(0xFFE89AB4),
                ),
                SizedBox(height: 22),
                CircularProgressIndicator(),
                SizedBox(height: 22),
                Text(
                  'Cerrando sesión...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Estamos limpiando tus credenciales de este dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
