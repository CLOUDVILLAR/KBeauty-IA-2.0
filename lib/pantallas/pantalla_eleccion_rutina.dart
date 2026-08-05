import 'package:flutter/material.dart';

import '../servicios/servicio_promotoras.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/selector_opcion.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

const List<String> _tiposPiel = ['seca', 'grasa', 'mixta', 'normal', 'sensible'];

/// La rutina siempre sale del analisis de las fotos (la condicion detectada
/// nunca se elige a mano). Esta pantalla solo le pide a la promotora que
/// confirme el tipo de piel para afinar la recomendacion; si no lo sabe, se
/// usa el tipo de piel que la misma IA estimo de las fotos.
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
  String? tipoPielElegido;
  bool guardando = false;

  Future<void> guardar({String? tipoPiel}) async {
    setState(() => guardando = true);
    try {
      final resultado = await guardarAnalisisPromotora(
        clienteNombre: widget.clienteNombre,
        clienteApellido: widget.clienteApellido,
        clienteTelefono: widget.clienteTelefono,
        resultadoIa: widget.resultadoIa,
        tipoPielSeleccionado: tipoPiel,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tipo de piel')),
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
                      'Que tipo de piel tiene la persona?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'La rutina se arma con el analisis de las fotos. Confirma el tipo de piel '
                      'para afinar la recomendacion.',
                    ),
                    const SizedBox(height: 18),
                    selectorOpcion(
                      etiqueta: 'Tipo de piel',
                      valor: tipoPielElegido,
                      opciones: _tiposPiel,
                      alCambiar: (valor) => setState(() => tipoPielElegido = valor),
                    ),
                    const SizedBox(height: 16),
                    botonPrincipal(
                      texto: 'Guardar',
                      icono: Icons.check_circle_outline,
                      cargando: guardando,
                      alPresionar: tipoPielElegido == null
                          ? null
                          : () => guardar(tipoPiel: tipoPielElegido),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: guardando ? null : () => guardar(tipoPiel: null),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('No lo se, que el analisis decida'),
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
