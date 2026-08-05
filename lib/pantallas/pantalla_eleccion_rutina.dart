import 'package:flutter/material.dart';

import '../servicios/servicio_promotoras.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/selector_opcion.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

/// Pregunta el tipo de piel de la persona mostrando los nombres reales de
/// las rutinas del JSON (ej. "Piel sensible con melasma"), para que la
/// promotora elija algo descriptivo y no un tipo generico. Si no lo sabe, la
/// IA decide con el mismo analisis de fotos (tipo de piel y condicion).
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
  List<String> rutinas = [];
  String? rutinaElegida;
  bool cargandoRutinas = true;
  bool guardando = false;
  String? errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarRutinas();
  }

  Future<void> _cargarRutinas() async {
    setState(() {
      cargandoRutinas = true;
      errorCarga = null;
    });
    try {
      final lista = await obtenerRutinasPromotoras();
      final nombres = lista
          .map((rutina) => (rutina['nombre'] ?? '').toString())
          .where((nombre) => nombre.isNotEmpty)
          .toList();
      if (mounted) setState(() => rutinas = nombres);
    } catch (error) {
      if (mounted) setState(() => errorCarga = error.toString());
    } finally {
      if (mounted) setState(() => cargandoRutinas = false);
    }
  }

  Future<void> guardar({String? nombreRutina}) async {
    setState(() => guardando = true);
    try {
      final resultado = await guardarAnalisisPromotora(
        clienteNombre: widget.clienteNombre,
        clienteApellido: widget.clienteApellido,
        clienteTelefono: widget.clienteTelefono,
        resultadoIa: widget.resultadoIa,
        rutinaNombre: nombreRutina,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisis(
            resultado: resultado,
            clienteNombre: widget.clienteNombre,
            clienteTelefono: widget.clienteTelefono,
          ),
        ),
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
                      'La rutina se arma con el analisis de las fotos. Elige la opcion que '
                      'mejor describe a la persona para afinar la recomendacion.',
                    ),
                    const SizedBox(height: 18),
                    if (cargandoRutinas) cargandoCentro('Cargando opciones...'),
                    if (!cargandoRutinas && errorCarga != null)
                      mensajeError('No se pudieron cargar las opciones: $errorCarga',
                          alReintentar: _cargarRutinas),
                    if (!cargandoRutinas && errorCarga == null) ...[
                      selectorOpcion(
                        etiqueta: 'Tipo de piel',
                        valor: rutinaElegida,
                        opciones: rutinas,
                        alCambiar: (valor) => setState(() => rutinaElegida = valor),
                      ),
                      const SizedBox(height: 16),
                      botonPrincipal(
                        texto: 'Guardar',
                        icono: Icons.check_circle_outline,
                        cargando: guardando,
                        alPresionar: rutinaElegida == null
                            ? null
                            : () => guardar(nombreRutina: rutinaElegida),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: guardando ? null : () => guardar(nombreRutina: null),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('No lo se, que el analisis decida'),
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
