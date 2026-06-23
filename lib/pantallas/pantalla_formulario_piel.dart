import 'package:flutter/material.dart';

import '../servicios/servicio_perfil.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/selector_opcion.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_dashboard.dart';

class PantallaFormularioPiel extends StatefulWidget {
  const PantallaFormularioPiel({super.key});

  @override
  State<PantallaFormularioPiel> createState() => _PantallaFormularioPielState();
}

class _PantallaFormularioPielState extends State<PantallaFormularioPiel> {
  bool cargando = true;
  bool guardando = false;
  String? tipoPiel;
  String? condicionPrincipal;
  String? rangoEdad;
  String? sensibilidad;
  String? usaProtectorSolar;
  List<String> tiposPiel = ['seca', 'grasa', 'mixta', 'normal', 'sensible'];
  List<String> condiciones = ['none', 'melasma', 'acné', 'manchas', 'arrugas', 'poros', 'opaca'];
  List<String> rangosEdad = ['18-24', '25-34', '35-44', '45+'];
  List<String> sensibilidades = ['baja', 'media', 'alta'];

  @override
  void initState() {
    super.initState();
    cargarOpciones();
  }

  Future<void> cargarOpciones() async {
    try {
      final opciones = await obtenerOpcionesPerfil();
      setState(() {
        tiposPiel = extraerOpciones(opciones, 'tipos_piel', tiposPiel);
        condiciones = extraerOpciones(opciones, 'condiciones', condiciones);
        rangosEdad = extraerOpciones(opciones, 'rangos_edad', rangosEdad);
        sensibilidades = extraerOpciones(opciones, 'sensibilidades', sensibilidades);
        cargando = false;
      });
    } catch (_) {
      setState(() => cargando = false);
    }
  }

  List<String> extraerOpciones(Map<String, dynamic> mapa, String clave, List<String> defecto) {
    final valor = mapa[clave];
    if (valor is List && valor.isNotEmpty) return valor.map((e) => e.toString()).toList();
    return defecto;
  }

  Future<void> guardar() async {
    if ([tipoPiel, condicionPrincipal, rangoEdad, sensibilidad, usaProtectorSolar].any((v) => textoSeguro(v).isEmpty)) {
      mostrarMensaje(context, 'Completa todas las opciones para continuar');
      return;
    }
    setState(() => guardando = true);
    try {
      await guardarFormularioPiel({
        'tipo_piel': tipoPiel,
        'condicion_principal': condicionPrincipal,
        'rango_edad': rangoEdad,
        'sensibilidad': sensibilidad,
        'usa_protector_solar': usaProtectorSolar == 'sí',
        'alergias': <String>[],
        'rutina_actual': '',
      });
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaDashboard()), (_) => false);
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return Scaffold(body: cargandoCentro('Preparando formulario...'));
    return Scaffold(
      appBar: AppBar(title: const Text('Tu perfil de piel')),
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
                    const Text('Cuéntanos lo básico', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Esto solo se llena la primera vez. La app lo usará para recomendar rutinas con más precisión.'),
                    const SizedBox(height: 18),
                    selectorOpcion(etiqueta: 'Tipo de piel', valor: tipoPiel, opciones: tiposPiel, alCambiar: (v) => setState(() => tipoPiel = v)),
                    const SizedBox(height: 14),
                    selectorOpcion(etiqueta: 'Condición principal', valor: condicionPrincipal, opciones: condiciones, alCambiar: (v) => setState(() => condicionPrincipal = v)),
                    const SizedBox(height: 14),
                    selectorOpcion(etiqueta: 'Rango de edad', valor: rangoEdad, opciones: rangosEdad, alCambiar: (v) => setState(() => rangoEdad = v)),
                    const SizedBox(height: 14),
                    selectorOpcion(etiqueta: 'Sensibilidad', valor: sensibilidad, opciones: sensibilidades, alCambiar: (v) => setState(() => sensibilidad = v)),
                    const SizedBox(height: 14),
                    selectorOpcion(etiqueta: '¿Usas protector solar?', valor: usaProtectorSolar, opciones: const ['sí', 'no'], alCambiar: (v) => setState(() => usaProtectorSolar = v)),
                    const SizedBox(height: 18),
                    botonPrincipal(texto: 'Guardar y entrar', icono: Icons.check_circle_outline, cargando: guardando, alPresionar: guardar),
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
