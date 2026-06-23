import 'package:flutter/material.dart';

import '../servicios/servicio_evolucion.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';

class PantallaEvolucion extends StatefulWidget {
  const PantallaEvolucion({super.key});

  @override
  State<PantallaEvolucion> createState() => _PantallaEvolucionState();
}

class _PantallaEvolucionState extends State<PantallaEvolucion> {
  late Future<Map<String, dynamic>> futuro;

  @override
  void initState() {
    super.initState();
    futuro = obtenerResumenEvolucion();
  }

  void _recargar() {
    setState(() => futuro = obtenerResumenEvolucion());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return cargandoCentro('Preparando tu progreso...');
            }

            if (snapshot.hasError) {
              return mensajeError(snapshot.error.toString(), alReintentar: _recargar);
            }

            final datos = snapshot.data ?? <String, dynamic>{};

            if (datos['hay_suficientes_datos'] == false) {
              return _SinHistorial(datos: datos, onRetry: _recargar);
            }

            return _ContenidoEvolucion(datos: datos, onRefresh: _recargar);
          },
        ),
      ),
    );
  }
}

class _ContenidoEvolucion extends StatelessWidget {
  const _ContenidoEvolucion({required this.datos, required this.onRefresh});

  final Map<String, dynamic> datos;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cambio = mapaSeguro(datos['cambio']);
    final resumenNumerico = mapaSeguro(datos['resumen_numerico']);
    final porcentaje = numeroSeguro(datos['porcentaje_general'] ?? cambio['porcentaje_general']);
    final metricas = _leerMetricas(datos, cambio);
    final mejoras = _leerListaPrioritaria(datos, cambio, 'mejoras_destacadas', metricas, estado: 'mejoro');
    final alertas = _leerListaPrioritaria(datos, cambio, 'alertas_destacadas', metricas, estado: 'empeoro');
    final anterior = mapaSeguro(datos['analisis_anterior']);
    final actual = mapaSeguro(datos['analisis_actual']);
    final resumen = textoSeguro(
      datos['resumen'] ?? cambio['resumen'],
      'Comparamos tus análisis para mostrarte avances reales sin saturarte de números.',
    );

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: centrarContenido(
        context,
        ListView(
          padding: margenPantalla(context),
          children: [
            _Encabezado(onRefresh: onRefresh),
            const SizedBox(height: 14),
            _HeroProgreso(
              porcentaje: porcentaje,
              resumen: resumen,
              anterior: anterior,
              actual: actual,
            ),
            const SizedBox(height: 2),
            _FilaResumen(
              mejoraron: resumenNumerico['mejoraron'] ?? cambio['metricas_mejoraron'],
              empeoraron: resumenNumerico['empeoraron'] ?? cambio['metricas_empeoraron'],
              estables: resumenNumerico['estables'] ?? cambio['metricas_estables'],
            ),
            if (mejoras.isNotEmpty) ...[
              tituloSeccion(
                'Mejoras visibles',
                icono: Icons.auto_graph_rounded,
                subtitulo: 'Lo positivo desde tu último análisis',
              ),
              _ListaTarjetasDestacadas(items: mejoras.take(4).toList(), tipo: _TipoTarjetaDestacada.mejora),
            ],
            if (alertas.isNotEmpty) ...[
              tituloSeccion(
                'Puntos a cuidar',
                icono: Icons.favorite_border_rounded,
                subtitulo: 'Áreas que necesitan constancia, no alarma',
              ),
              _ListaTarjetasDestacadas(items: alertas.take(4).toList(), tipo: _TipoTarjetaDestacada.alerta),
            ],
            if (metricas.isNotEmpty) ...[
              tituloSeccion(
                'Resumen por área',
                icono: Icons.stacked_bar_chart_rounded,
                subtitulo: 'Valores mostrados como estado: mayor es mejor',
              ),
              _TarjetaAreas(metricas: metricas),
            ],
            _TarjetaProximoAnalisis(actual: actual),
            const SizedBox(height: 8),
            _NotaCalculo(
              texto: textoSeguro(
                cambio['nota_calculo'],
                'Los valores se muestran de forma positiva para que sea fácil de entender: 100 significa mejor estado y 0 necesita más apoyo.',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _leerMetricas(Map<String, dynamic> datos, Map<String, dynamic> cambio) {
    final lista = listaMapas(datos['metricas_lista'] ?? cambio['metricas_lista']);
    if (lista.isNotEmpty) return lista;

    final mapa = mapaSeguro(datos['metricas'] ?? datos['cambios'] ?? cambio['metricas']);
    return mapa.entries.map((e) {
      final valor = mapaSeguro(e.value);
      valor['clave'] = valor['clave'] ?? e.key;
      valor['nombre'] = valor['nombre'] ?? _nombreDesdeClave(e.key.toString());
      return valor;
    }).toList();
  }

  List<Map<String, dynamic>> _leerListaPrioritaria(
    Map<String, dynamic> datos,
    Map<String, dynamic> cambio,
    String llave,
    List<Map<String, dynamic>> metricas, {
    required String estado,
  }) {
    final lista = listaMapas(datos[llave] ?? cambio[llave]);
    if (lista.isNotEmpty) return lista;

    final filtradas = metricas.where((m) => textoSeguro(m['estado']) == estado).toList();
    filtradas.sort((a, b) {
      final pa = numeroSeguro(a['porcentaje_mejora']).abs();
      final pb = numeroSeguro(b['porcentaje_mejora']).abs();
      return pb.compareTo(pa);
    });
    return filtradas;
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evolución', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text('Tus avances, explicado simple', style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Actualizar',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _HeroProgreso extends StatelessWidget {
  const _HeroProgreso({
    required this.porcentaje,
    required this.resumen,
    required this.anterior,
    required this.actual,
  });

  final double porcentaje;
  final String resumen;
  final Map<String, dynamic> anterior;
  final Map<String, dynamic> actual;

  @override
  Widget build(BuildContext context) {
    final estado = _estadoGeneral(porcentaje);

    return tarjetaGradiente(
      relleno: const EdgeInsets.all(22),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MedidorHero(valor: porcentaje),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado.titulo,
                      style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      estado.subtitulo,
                      style: TextStyle(color: Colors.white.withOpacity(.88), height: 1.35, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(resumen, style: const TextStyle(color: Colors.white, height: 1.42, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _FechaHero(titulo: 'Antes', fecha: anterior['creado_en'])),
              const SizedBox(width: 10),
              Expanded(child: _FechaHero(titulo: 'Ahora', fecha: actual['creado_en'])),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedidorHero extends StatelessWidget {
  const _MedidorHero({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) {
    final progreso = (valor.abs() / 40).clamp(0.0, 1.0);
    final texto = valor.abs().toStringAsFixed(valor.abs() >= 10 ? 0 : 1);

    return Container(
      width: 94,
      height: 94,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(.26)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: progreso,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
              Text('%', style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FechaHero extends StatelessWidget {
  const _FechaHero({required this.titulo, required this.fecha});

  final String titulo;
  final dynamic fecha;

  @override
  Widget build(BuildContext context) {
    final fechaTexto = _soloFecha(fecha);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(fechaTexto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.mejoraron, required this.empeoraron, required this.estables});

  final dynamic mejoraron;
  final dynamic empeoraron;
  final dynamic estables;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniResumen(
            numero: numeroSeguro(mejoraron).toStringAsFixed(0),
            texto: 'mejoras',
            icono: Icons.trending_up_rounded,
            color: KBeautyColors.rojo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniResumen(
            numero: numeroSeguro(empeoraron).toStringAsFixed(0),
            texto: 'a cuidar',
            icono: Icons.favorite_border_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniResumen(
            numero: numeroSeguro(estables).toStringAsFixed(0),
            texto: 'estables',
            icono: Icons.remove_rounded,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _MiniResumen extends StatelessWidget {
  const _MiniResumen({required this.numero, required this.texto, required this.icono, required this.color});

  final String numero;
  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return tarjetaBase(
      relleno: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      hijo: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(15)),
            child: Icon(icono, color: color, size: 19),
          ),
          const SizedBox(height: 8),
          Text(numero, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

enum _TipoTarjetaDestacada { mejora, alerta }

class _ListaTarjetasDestacadas extends StatelessWidget {
  const _ListaTarjetasDestacadas({required this.items, required this.tipo});

  final List<Map<String, dynamic>> items;
  final _TipoTarjetaDestacada tipo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((m) => _TarjetaDestacada(metrica: m, tipo: tipo)).toList(),
    );
  }
}

class _TarjetaDestacada extends StatelessWidget {
  const _TarjetaDestacada({required this.metrica, required this.tipo});

  final Map<String, dynamic> metrica;
  final _TipoTarjetaDestacada tipo;

  @override
  Widget build(BuildContext context) {
    final nombre = textoSeguro(metrica['nombre'] ?? metrica['clave'], 'Área');
    final antes = _estadoVisual(numeroSeguro(metrica['antes']));
    final ahora = _estadoVisual(numeroSeguro(metrica['actual']));
    final cambio = (ahora - antes).abs();
    final porcentaje = numeroSeguro(metrica['porcentaje_mejora']).abs();
    final esMejora = tipo == _TipoTarjetaDestacada.mejora;
    final color = esMejora ? KBeautyColors.rojo : const Color(0xFFF59E0B);
    final icono = esMejora ? Icons.check_rounded : Icons.info_outline_rounded;
    final titulo = esMejora ? '$nombre va mejor' : '$nombre necesita constancia';
    final texto = esMejora
        ? 'Subió ${cambio.toStringAsFixed(0)} puntos de estado. Mejora estimada: ${porcentaje.toStringAsFixed(1)}%.'
        : 'Bajó ${cambio.toStringAsFixed(0)} puntos de estado. Dale seguimiento sin cambiar todo de golpe.';

    return tarjetaBase(
      relleno: const EdgeInsets.all(17),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(17)),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              _Pill(texto: '${ahora.toStringAsFixed(0)}/100', color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(texto, style: const TextStyle(color: KBeautyColors.textoSuave, height: 1.35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _ComparadorCompacto(antes: antes, ahora: ahora, color: color),
        ],
      ),
    );
  }
}

class _TarjetaAreas extends StatelessWidget {
  const _TarjetaAreas({required this.metricas});

  final List<Map<String, dynamic>> metricas;

  @override
  Widget build(BuildContext context) {
    final ordenadas = [...metricas];
    ordenadas.sort((a, b) {
      final aa = _estadoVisual(numeroSeguro(a['actual']));
      final bb = _estadoVisual(numeroSeguro(b['actual']));
      return aa.compareTo(bb);
    });

    return tarjetaBase(
      relleno: const EdgeInsets.all(18),
      hijo: Column(
        children: ordenadas.map((m) {
          final nombre = textoSeguro(m['nombre'] ?? m['clave'], 'Área');
          final antes = _estadoVisual(numeroSeguro(m['antes']));
          final ahora = _estadoVisual(numeroSeguro(m['actual']));
          final estado = textoSeguro(m['estado']);
          final color = _colorEstado(ahora, estado);
          final icono = _iconoEstado(estado, ahora);

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icono, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w900))),
                    Text('${ahora.toStringAsFixed(0)}/100', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                _ComparadorCompacto(antes: antes, ahora: ahora, color: color),
                const SizedBox(height: 6),
                Text(_fraseEstado(ahora, estado), style: const TextStyle(color: KBeautyColors.textoSuave, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ComparadorCompacto extends StatelessWidget {
  const _ComparadorCompacto({required this.antes, required this.ahora, required this.color});

  final double antes;
  final double ahora;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BarraLinea(etiqueta: 'Antes', valor: antes, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 7),
        _BarraLinea(etiqueta: 'Ahora', valor: ahora, color: color),
      ],
    );
  }
}

class _BarraLinea extends StatelessWidget {
  const _BarraLinea({required this.etiqueta, required this.valor, required this.color});

  final String etiqueta;
  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progreso = (valor / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(etiqueta, style: const TextStyle(fontSize: 11, color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 9,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(valor.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _TarjetaProximoAnalisis extends StatelessWidget {
  const _TarjetaProximoAnalisis({required this.actual});

  final Map<String, dynamic> actual;

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(textoSeguro(actual['creado_en']));
    final proxima = fecha?.add(const Duration(days: 30));
    final textoFecha = proxima == null ? 'en 30 días' : _soloFecha(proxima.toIso8601String());

    return tarjetaSuave(
      hijo: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KBeautyColors.rojo.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: KBeautyColors.rojo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próximo seguimiento', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 5),
                Text('Repite tu foto alrededor de $textoFecha para comparar con más precisión.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _Pill(texto: 'luz similar', color: KBeautyColors.rojo),
                    _Pill(texto: 'rostro limpio', color: KBeautyColors.rojo),
                    _Pill(texto: 'sin filtros', color: KBeautyColors.rojo),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.13)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}

class _NotaCalculo extends StatelessWidget {
  const _NotaCalculo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        texto,
        style: const TextStyle(color: KBeautyColors.textoSuave, height: 1.35, fontSize: 12, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SinHistorial extends StatelessWidget {
  const _SinHistorial({required this.datos, required this.onRetry});

  final Map<String, dynamic> datos;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return centrarContenido(
      context,
      ListView(
        padding: margenPantalla(context),
        children: [
          _Encabezado(onRefresh: onRetry),
          const SizedBox(height: 18),
          tarjetaGradiente(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aún no hay suficiente historial',
                  style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  textoSeguro(datos['mensaje'], 'Necesitamos al menos dos análisis para mostrar tu evolución real.'),
                  style: TextStyle(color: Colors.white.withOpacity(.92), height: 1.4, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          tarjetaBase(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cómo preparar tu próxima comparación', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const _ConsejoItem(icono: Icons.calendar_month_rounded, texto: 'Haz tu próximo análisis en 30 días.'),
                const _ConsejoItem(icono: Icons.wb_sunny_outlined, texto: 'Usa una luz parecida a la foto anterior.'),
                const _ConsejoItem(icono: Icons.face_retouching_natural_rounded, texto: 'Evita filtros o maquillaje fuerte.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsejoItem extends StatelessWidget {
  const _ConsejoItem({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: KBeautyColors.rojoSuave, borderRadius: BorderRadius.circular(13)),
            child: Icon(icono, color: KBeautyColors.rojo, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _EstadoHero {
  const _EstadoHero(this.titulo, this.subtitulo);

  final String titulo;
  final String subtitulo;
}

_EstadoHero _estadoGeneral(double porcentaje) {
  if (porcentaje > 5) return const _EstadoHero('Tu piel va mejorando', 'Hay señales positivas en tu progreso. Sigue con constancia.');
  if (porcentaje < -5) return const _EstadoHero('Vamos a cuidar esta etapa', 'Algunas áreas necesitan más apoyo esta vez.');
  return const _EstadoHero('Tu piel está estable', 'Los cambios son suaves. La constancia sigue siendo la clave.');
}

double _estadoVisual(double valorProblema) {
  return (100 - valorProblema).clamp(0.0, 100.0);
}

Color _colorEstado(double valor, String estado) {
  if (estado == 'mejoro') return KBeautyColors.rojo;
  if (estado == 'empeoro') return const Color(0xFFF59E0B);
  if (valor >= 82) return const Color(0xFF10B981);
  if (valor >= 65) return const Color(0xFF3B82F6);
  if (valor >= 45) return const Color(0xFFF59E0B);
  return KBeautyColors.rojo;
}

IconData _iconoEstado(String estado, double valor) {
  if (estado == 'mejoro') return Icons.trending_up_rounded;
  if (estado == 'empeoro') return Icons.favorite_border_rounded;
  if (valor >= 65) return Icons.check_rounded;
  return Icons.spa_outlined;
}

String _fraseEstado(double valor, String estado) {
  if (estado == 'mejoro') return 'Mejoró desde tu análisis anterior.';
  if (estado == 'empeoro') return 'Necesita seguimiento y una rutina constante.';
  if (valor >= 82) return 'Se mantiene muy bien.';
  if (valor >= 65) return 'Va en buen camino.';
  if (valor >= 45) return 'Puede mejorar con constancia.';
  return 'Conviene darle prioridad.';
}

String _soloFecha(dynamic fecha) {
  final texto = fechaBonita(fecha);
  if (texto.trim().isEmpty) return 'No disponible';
  return texto.split(' ').first;
}

String _nombreDesdeClave(String clave) {
  return clave
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
