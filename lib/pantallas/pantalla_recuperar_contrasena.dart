import 'package:flutter/material.dart';

import '../servicios/servicio_auth.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';

class PantallaRecuperarContrasena extends StatefulWidget {
  const PantallaRecuperarContrasena({super.key});

  @override
  State<PantallaRecuperarContrasena> createState() => _PantallaRecuperarContrasenaState();
}

class _PantallaRecuperarContrasenaState extends State<PantallaRecuperarContrasena> {
  bool cargando = false;

  Future<void> abrirRecuperacionWeb() async {
    setState(() => cargando = true);
    try {
      await ServicioAuth.abrirRecuperarPassword();
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              tarjetaBase(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Recuperación centralizada',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La recuperación de contraseña se hace en Villar.do. KBeauty no solicita ni guarda tu contraseña.',
                    ),
                    const SizedBox(height: 18),
                    botonPrincipal(
                      texto: 'Abrir recuperación Villar.do',
                      icono: Icons.open_in_browser,
                      cargando: cargando,
                      alPresionar: abrirRecuperacionWeb,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
