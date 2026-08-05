import 'package:flutter/material.dart';

import '../tema/tema_app.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import 'pantalla_datos_cliente.dart';
import 'pantalla_historial_promotoras.dart';

/// Home de la app de promotoras: sin login, entra directo aqui.
class PantallaInicioPromotoras extends StatelessWidget {
  const PantallaInicioPromotoras({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: centrarContenido(
          context,
          Padding(
            padding: margenPantalla(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 96,
                  color: KBeautyColors.rojo,
                ),
                const SizedBox(height: 24),
                const Text(
                  'KBeauty Promotoras',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Analiza la piel de un cliente nuevo y asignale una rutina.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                botonPrincipal(
                  texto: 'Nuevo analisis',
                  icono: Icons.add_a_photo_outlined,
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PantallaDatosCliente()),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PantallaHistorialPromotoras()),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Ver historial'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
