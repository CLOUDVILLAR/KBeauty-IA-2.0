import 'package:flutter/material.dart';

import '../servicios/servicio_promotoras.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/selector_opcion.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_captura_promotoras.dart';

/// Pregunta el tipo de piel ANTES de tomar las fotos, mostrando los nombres
/// reales de las rutinas del JSON (ej. "Piel sensible con melasma"). No
/// guarda nada todavia: solo lleva la eleccion (o null si "No lo se") hasta
/// la pantalla de captura, para que el analisis y el guardado se hagan
/// juntos al final y se muestre el resultado completo de una sola vez.
class PantallaEleccionRutina extends StatefulWidget {
  const PantallaEleccionRutina({
    super.key,
    required this.clienteNombre,
    required this.clienteApellido,
    required this.clienteTelefono,
  });

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

  void continuar({String? nombreRutina}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCapturaPromotoras(
          clienteNombre: widget.clienteNombre,
          clienteApellido: widget.clienteApellido,
          clienteTelefono: widget.clienteTelefono,
          rutinaElegida: nombreRutina,
        ),
      ),
    );
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
                      'La rutina se arma con el analisis de las fotos que vas a tomar. '
                      'Elige la opcion que mejor describe a la persona para afinar la '
                      'recomendacion.',
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
                        texto: 'Continuar a las fotos',
                        icono: Icons.arrow_forward_rounded,
                        alPresionar: rutinaElegida == null
                            ? null
                            : () => continuar(nombreRutina: rutinaElegida),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => continuar(nombreRutina: null),
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
