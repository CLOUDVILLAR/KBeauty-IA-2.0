import 'package:flutter/material.dart';

import '../servicios/servicio_promotoras.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/selector_opcion.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

/// Deja elegir entre rutina automatica (segun el analisis de IA) o manual
/// (de la lista completa de rutinas), y guarda el analisis del cliente
/// walk-in en la API de promotoras.
class PantallaEleccionRutina extends StatefulWidget {
  const PantallaEleccionRutina({
    super.key,
    required this.resultadoIa,
    required this.clienteNombre,
    required this.clienteApellido,
    required this.clienteTelefono,
  });

  final Map<String, dynamic> resultadoIa;
  final String clienteNombre;
  final String clienteApellido;
  final String clienteTelefono;

  @override
  State<PantallaEleccionRutina> createState() => _PantallaEleccionRutinaState();
}

class _PantallaEleccionRutinaState extends State<PantallaEleccionRutina> {
  List<Map<String, dynamic>>? rutinas;
  String? rutinaSeleccionada;
  bool cargandoRutinas = false;
  bool guardando = false;

  Future<void> cargarRutinas() async {
    setState(() => cargandoRutinas = true);
    try {
      final lista = await obtenerRutinasPromotoras();
      if (mounted) setState(() => rutinas = lista);
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudieron cargar las rutinas: $error');
      }
    } finally {
      if (mounted) setState(() => cargandoRutinas = false);
    }
  }

  Future<void> guardar({required String modo}) async {
    if (modo == 'manual' && (rutinaSeleccionada == null || rutinaSeleccionada!.isEmpty)) {
      mostrarMensaje(context, 'Selecciona una rutina de la lista.');
      return;
    }

    setState(() => guardando = true);
    try {
      final resultado = await guardarAnalisisPromotora(
        clienteNombre: widget.clienteNombre,
        clienteApellido: widget.clienteApellido,
        clienteTelefono: widget.clienteTelefono,
        resultadoIa: widget.resultadoIa,
        modoRutina: modo,
        rutinaNombre: modo == 'manual' ? rutinaSeleccionada : null,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => PantallaResultadoAnalisis(resultado: resultado)),
        (ruta) => false,
      );
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo guardar el analisis: $error');
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Widget construirSelectorRutinas() {
    final lista = rutinas;
    if (lista == null) return const SizedBox.shrink();

    final opciones = lista
        .map((rutina) => (rutina['nombre'] ?? '').toString())
        .where((nombre) => nombre.isNotEmpty)
        .toList();

    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona una rutina', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          selectorOpcion(
            etiqueta: 'Rutina',
            valor: rutinaSeleccionada,
            opciones: opciones,
            alCambiar: (valor) => setState(() => rutinaSeleccionada = valor),
          ),
          const SizedBox(height: 16),
          botonPrincipal(
            texto: 'Guardar con esta rutina',
            icono: Icons.check_circle_outline,
            cargando: guardando,
            alPresionar: () => guardar(modo: 'manual'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir rutina')),
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              tarjetaBase(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Como asignamos la rutina?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Puedes dejar que el sistema elija segun el analisis, o elegirla tu misma de la lista.',
                    ),
                    const SizedBox(height: 20),
                    botonPrincipal(
                      texto: 'Rutina automatica',
                      icono: Icons.auto_awesome,
                      cargando: guardando,
                      alPresionar: () => guardar(modo: 'automatica'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: guardando || cargandoRutinas
                          ? null
                          : () {
                              if (rutinas == null) cargarRutinas();
                            },
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Elegir manualmente'),
                    ),
                  ],
                ),
              ),
              if (cargandoRutinas) cargandoCentro('Cargando rutinas...'),
              if (rutinas != null && !cargandoRutinas) construirSelectorRutinas(),
            ],
          ),
        ),
      ),
    );
  }
}
