import 'package:flutter/material.dart';

import '../servicios/servicio_auth.dart';
import '../servicios/servicio_perfil.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_formulario_piel.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  bool cargando = false;
  bool cancelando = false;

  Future<void> _continuarLuegoDeVillarDo() async {
    final estado = await obtenerEstadoPerfil();
    final completado = estado['formulario_completado'] == true || estado['completado'] == true;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => completado ? const PantallaDashboard() : const PantallaFormularioPiel()),
      (_) => false,
    );
  }

  Future<void> abrirRegistroWeb() async {
    setState(() => cargando = true);
    var mantenerEsperaCallback = false;
    try {
      final sesionCompletada = await ServicioAuth.abrirRegistroVillarDo();
      mantenerEsperaCallback = !sesionCompletada;
      if (sesionCompletada) await _continuarLuegoDeVillarDo();
    } catch (error) {
      mantenerEsperaCallback = false;
      final texto = error.toString().replaceFirst('Exception: ', '');
      if (mounted && texto.isNotEmpty && !cancelando) mostrarMensaje(context, texto);
    } finally {
      if (mounted) setState(() {
        cargando = mantenerEsperaCallback;
        cancelando = false;
      });
    }
  }

  Future<void> cancelarRegistroWeb() async {
    setState(() {
      cargando = false;
      cancelando = true;
    });
    await ServicioAuth.cancelarAutenticacionWeb();
    if (!mounted) return;
    mostrarMensaje(context, 'Registro cancelado. Puedes intentarlo de nuevo.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta Villar.do')),
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
                      'Registro centralizado',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El registro se realiza exclusivamente en Villar.do. Al terminar, volverás automáticamente a KBeauty IA.',
                    ),
                    const SizedBox(height: 18),
                    botonPrincipal(
                      texto: 'Abrir registro Villar.do',
                      icono: Icons.open_in_browser,
                      cargando: cargando,
                      alPresionar: abrirRegistroWeb,
                    ),
                    if (cargando) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Esperando el registro web de Villar.do. Si cierras el navegador, cancela este intento para volver a la pantalla.',
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: cancelarRegistroWeb,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar registro'),
                      ),
                    ],
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
