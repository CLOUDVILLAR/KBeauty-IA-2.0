import 'package:flutter/material.dart';

import '../servicios/servicio_rutinas.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import '../widgets/tarjeta_rutina.dart';

class PantallaRutina extends StatefulWidget {
  const PantallaRutina({super.key});

  @override
  State<PantallaRutina> createState() => _PantallaRutinaState();
}

class _PantallaRutinaState extends State<PantallaRutina> {
  late Future<Map<String, dynamic>> futuro;

  @override
  void initState() {
    super.initState();
    futuro = obtenerRutinaRecomendada();
  }

  Future<void> _recargar() async {
    setState(() => futuro = obtenerRutinaRecomendada());
    await futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KBeautyColors.fondo,
      appBar: AppBar(
        title: const Text('Mi rutina'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => setState(() => futuro = obtenerRutinaRecomendada()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return cargandoCentro('Preparando tu rutina...');
          }

          if (snapshot.hasError) {
            return mensajeError(
              snapshot.error.toString(),
              alReintentar: () => setState(() => futuro = obtenerRutinaRecomendada()),
            );
          }

          final datos = snapshot.data ?? <String, dynamic>{};
          final resumen = _resumenRutina(datos);
          final tipoPiel = textoSeguro(datos['tipo_piel'], 'Tu piel');
          final condicion = textoSeguro(datos['condicion'] ?? datos['condicion_principal'], 'Rutina personalizada');
          final nombre = textoSeguro(datos['nombre'] ?? datos['nombre_rutina'], 'Rutina recomendada');

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _recargar,
              color: KBeautyColors.rojo,
              child: centrarContenido(
                context,
                ListView(
                  padding: margenPantalla(context),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _HeroRutina(
                      nombre: nombre,
                      tipoPiel: tipoPiel,
                      condicion: condicion,
                      totalProductos: resumen.totalProductos,
                      totalMomentos: resumen.totalMomentos,
                    ),
                    _ResumenRapidoRutina(resumen: resumen),
                    tituloSeccion(
                      'Plan del dia',
                      icono: Icons.spa_rounded,
                      subtitulo: 'Sigue los pasos en orden. Lo importante es constancia, no saturar la piel.',
                    ),
                    tarjetaRutina(datos),
                    _ConsejoFinalRutina(totalProductos: resumen.totalProductos),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _ResumenRutina _resumenRutina(Map<String, dynamic> datos) {
    final contenedor = mapaSeguro(datos['rutina_completa'] ?? datos['rutina'] ?? datos);
    final momentos = mapaSeguro(contenedor['rutina'] ?? contenedor);
    const bloques = ['mañana', 'día', 'noche'];

    var totalProductos = 0;
    var totalMomentos = 0;

    for (final momento in bloques) {
      final productos = listaMapas(momentos[momento] ?? datos[momento]);
      if (productos.isNotEmpty) {
        totalMomentos++;
        totalProductos += productos.length;
      }
    }

    return _ResumenRutina(totalProductos: totalProductos, totalMomentos: totalMomentos);
  }
}

class _ResumenRutina {
  const _ResumenRutina({required this.totalProductos, required this.totalMomentos});

  final int totalProductos;
  final int totalMomentos;
}

class _HeroRutina extends StatelessWidget {
  const _HeroRutina({
    required this.nombre,
    required this.tipoPiel,
    required this.condicion,
    required this.totalProductos,
    required this.totalMomentos,
  });

  final String nombre;
  final String tipoPiel;
  final String condicion;
  final int totalProductos;
  final int totalMomentos;

  @override
  Widget build(BuildContext context) {
    return tarjetaGradiente(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(.20)),
                ),
                child: const Icon(Icons.local_florist_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.05),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      condicion,
                      style: TextStyle(color: Colors.white.withOpacity(.86), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Plan claro para $tipoPiel. Usa cada paso en su momento y evita mezclar demasiados activos a la vez.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PildoraHero(texto: '$totalProductos productos'),
              _PildoraHero(texto: '$totalMomentos momentos'),
              const _PildoraHero(texto: 'Rutina guiada'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PildoraHero extends StatelessWidget {
  const _PildoraHero({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _ResumenRapidoRutina extends StatelessWidget {
  const _ResumenRapidoRutina({required this.resumen});

  final _ResumenRutina resumen;

  @override
  Widget build(BuildContext context) {
    return tarjetaBase(
      relleno: const EdgeInsets.all(18),
      hijo: Row(
        children: [
          Expanded(
            child: _MiniDatoRutina(
              icono: Icons.inventory_2_rounded,
              titulo: 'Productos',
              valor: resumen.totalProductos.toString(),
              color: KBeautyColors.rojo,
            ),
          ),
          Container(width: 1, height: 54, color: KBeautyColors.borde),
          Expanded(
            child: _MiniDatoRutina(
              icono: Icons.schedule_rounded,
              titulo: 'Momentos',
              valor: resumen.totalMomentos.toString(),
              color: const Color(0xFF7C3AED),
            ),
          ),
          Container(width: 1, height: 54, color: KBeautyColors.borde),
          const Expanded(
            child: _MiniDatoRutina(
              icono: Icons.repeat_rounded,
              titulo: 'Clave',
              valor: 'Constancia',
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDatoRutina extends StatelessWidget {
  const _MiniDatoRutina({required this.icono, required this.titulo, required this.valor, required this.color});

  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icono, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(valor, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 2),
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: KBeautyColors.textoSuave, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ConsejoFinalRutina extends StatelessWidget {
  const _ConsejoFinalRutina({required this.totalProductos});

  final int totalProductos;

  @override
  Widget build(BuildContext context) {
    final texto = totalProductos == 0
        ? 'Cuando tengas una rutina generada por IA, aparecerá aquí con pasos claros por momento del día.'
        : 'Haz una foto de seguimiento en unos 30 días para comparar si la rutina está ayudando a tu piel.';

    return tarjetaSuave(
      hijo: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KBeautyColors.rojoSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: KBeautyColors.rojo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Consejo de seguimiento', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(texto, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
