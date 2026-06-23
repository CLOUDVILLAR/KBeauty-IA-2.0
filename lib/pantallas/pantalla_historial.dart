import 'package:flutter/material.dart';

import '../servicios/servicio_analisis.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  late Future<List<Map<String, dynamic>>> futuro;

  @override
  void initState() {
    super.initState();
    futuro = obtenerHistorialAnalisis();
  }

  Future<void> _recargar() async {
    setState(() => futuro = obtenerHistorialAnalisis());
    await futuro;
  }

  Future<void> abrirDetalle(Map<String, dynamic> item) async {
    try {
      final id = textoSeguro(item['id']);
      final detalle = id.isEmpty ? item : await obtenerDetalleAnalisis(id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisis(resultado: detalle),
        ),
      );
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _resumen(Map<String, dynamic> item) {
    final opciones = [
      item['resumen_usuario'],
      item['resumen_general'],
      item['diagnostico'],
      item['descripcion'],
      item['conclusion'],
    ];

    for (final opcion in opciones) {
      final texto = textoSeguro(opcion);
      if (texto.isNotEmpty) return texto;
    }

    return 'Toca para ver el resultado completo, rutina recomendada y detalle del análisis.';
  }

  String _fecha(Map<String, dynamic> item) {
    final fecha = fechaBonita(
      item['creado_en'] ?? item['fecha'] ?? item['created_at'] ?? item['fecha_analisis'],
    );
    return fecha.isEmpty ? 'Fecha no disponible' : fecha;
  }

  double _puntaje(Map<String, dynamic> item) {
    final posibles = [
      item['puntaje_general'],
      item['estado_general'],
      item['score_general'],
      item['puntuacion_general'],
      item['porcentaje_general'],
    ];

    for (final valor in posibles) {
      final numero = _leerNumero(valor);
      if (numero > 0) return numero.clamp(0, 100);
    }

    final metricas = mapaSeguro(item['metricas']);
    if (metricas.isNotEmpty) {
      final valores = metricas.values.map(_leerNumero).where((v) => v > 0).toList();
      if (valores.isNotEmpty) {
        final suma = valores.fold<double>(0, (a, b) => a + b);
        return (suma / valores.length).clamp(0, 100);
      }
    }

    return 0;
  }

  double _leerNumero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    final texto = textoSeguro(valor).replaceAll('%', '').replaceAll(',', '.');
    return double.tryParse(texto) ?? 0;
  }

  String _estadoPuntaje(double valor) {
    if (valor >= 80) return 'Muy bien';
    if (valor >= 65) return 'Estable';
    if (valor >= 45) return 'En progreso';
    if (valor > 0) return 'Necesita apoyo';
    return 'Ver detalle';
  }

  Color _colorPuntaje(double valor) {
    if (valor >= 80) return const Color(0xFF10B981);
    if (valor >= 65) return KBeautyColors.rojo;
    if (valor >= 45) return const Color(0xFFF59E0B);
    if (valor > 0) return const Color(0xFFEF4444);
    return KBeautyColors.textoSuave;
  }

  List<String> _prioridades(Map<String, dynamic> item) {
    final fuentes = [
      item['prioridades'],
      item['problemas_detectados'],
      item['objetivos_piel'],
      item['objetivos'],
    ];

    final resultado = <String>[];
    for (final fuente in fuentes) {
      if (fuente is List) {
        for (final itemFuente in fuente) {
          final texto = _limpiarEtiqueta(textoSeguro(itemFuente));
          if (texto.isNotEmpty && !resultado.contains(texto)) resultado.add(texto);
        }
      }
    }

    final metricas = mapaSeguro(item['metricas']);
    if (resultado.isEmpty && metricas.isNotEmpty) {
      final ordenadas = metricas.entries.toList()
        ..sort((a, b) => _leerNumero(a.value).compareTo(_leerNumero(b.value)));
      for (final entrada in ordenadas.take(3)) {
        final texto = _limpiarEtiqueta(entrada.key);
        if (texto.isNotEmpty && !resultado.contains(texto)) resultado.add(texto);
      }
    }

    return resultado.take(3).toList();
  }

  String _limpiarEtiqueta(String texto) {
    final limpio = texto.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (limpio.isEmpty) return '';
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  Map<String, int> _resumenDatos(List<Map<String, dynamic>> datos) {
    final conPuntaje = datos.where((item) => _puntaje(item) > 0).length;
    return {
      'total': datos.length,
      'conPuntaje': conPuntaje,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return cargandoCentro('Cargando historial...');
          }

          if (snapshot.hasError) {
            return mensajeError(
              snapshot.error.toString(),
              alReintentar: () => setState(() => futuro = obtenerHistorialAnalisis()),
            );
          }

          final datos = snapshot.data ?? [];

          if (datos.isEmpty) {
            return _HistorialVacio(onRetry: _recargar);
          }

          final resumen = _resumenDatos(datos);
          final ultimo = datos.first;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _recargar,
              color: KBeautyColors.rojo,
              child: centrarContenido(
                context,
                ListView(
                  padding: margenPantalla(context),
                  children: [
                    tarjetaGradiente(
                      hijo: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(.20)),
                                ),
                                child: const Icon(Icons.history_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tu historial de piel',
                                      style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${resumen['total']} análisis guardados',
                                      style: TextStyle(color: Colors.white.withOpacity(.88), fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ChipHero(texto: 'Último: ${_fecha(ultimo)}'),
                              if ((resumen['conPuntaje'] ?? 0) > 0) _ChipHero(texto: '${resumen['conPuntaje']} con puntaje'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    tituloSeccion(
                      'Análisis anteriores',
                      icono: Icons.auto_graph_rounded,
                      subtitulo: 'Revisa tus resultados sin perder la rutina recomendada.',
                    ),
                    ...datos.asMap().entries.map((entrada) {
                      final indice = entrada.key;
                      final item = entrada.value;
                      return _TarjetaHistorial(
                        item: item,
                        indice: indice,
                        fecha: _fecha(item),
                        resumen: _resumen(item),
                        puntaje: _puntaje(item),
                        estado: _estadoPuntaje(_puntaje(item)),
                        colorEstado: _colorPuntaje(_puntaje(item)),
                        prioridades: _prioridades(item),
                        onTap: () => abrirDetalle(item),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipHero extends StatelessWidget {
  const _ChipHero({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20)),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _TarjetaHistorial extends StatelessWidget {
  const _TarjetaHistorial({
    required this.item,
    required this.indice,
    required this.fecha,
    required this.resumen,
    required this.puntaje,
    required this.estado,
    required this.colorEstado,
    required this.prioridades,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final int indice;
  final String fecha;
  final String resumen;
  final double puntaje;
  final String estado;
  final Color colorEstado;
  final List<String> prioridades;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esReciente = indice == 0;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: tarjetaBase(
        relleno: const EdgeInsets.all(18),
        hijo: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: esReciente ? KBeautyColors.rojoSuave : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    esReciente ? Icons.stars_rounded : Icons.event_note_rounded,
                    color: esReciente ? KBeautyColors.rojo : KBeautyColors.textoSuave,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              esReciente ? 'Análisis más reciente' : 'Análisis ${indice + 1}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: KBeautyColors.textoSuave),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(fecha, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              resumen,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600, color: KBeautyColors.texto),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniEstado(
                  etiqueta: 'Estado',
                  valor: estado,
                  color: colorEstado,
                ),
                if (puntaje > 0) ...[
                  const SizedBox(width: 10),
                  _MiniEstado(
                    etiqueta: 'Piel',
                    valor: '${puntaje.round()}%',
                    color: KBeautyColors.rojo,
                  ),
                ],
              ],
            ),
            if (prioridades.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prioridades.map((prioridad) => chipSuave(prioridad, icono: Icons.spa_rounded)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniEstado extends StatelessWidget {
  const _MiniEstado({required this.etiqueta, required this.valor, required this.color});

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: TextStyle(color: color.withOpacity(.86), fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _HistorialVacio extends StatelessWidget {
  const _HistorialVacio({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRetry,
        color: KBeautyColors.rojo,
        child: ListView(
          padding: margenPantalla(context),
          children: [
            const SizedBox(height: 34),
            tarjetaBase(
              relleno: const EdgeInsets.all(24),
              hijo: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: KBeautyColors.rojoSuave,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.history_rounded, color: KBeautyColors.rojo, size: 34),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Aún no tienes historial',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuando hagas tu primer análisis, aparecerá aquí para que puedas volver a ver tu resultado y tu rutina recomendada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
