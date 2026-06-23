import 'package:flutter/material.dart';

import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/tarjeta_base.dart';
import '../widgets/tarjeta_rutina.dart';

class PantallaResultadoAnalisis extends StatelessWidget {
  final Map<String, dynamic> resultado;

  const PantallaResultadoAnalisis({super.key, required this.resultado});

  static const Color rojoMarca = Color(0xFFDC1015);
  static const Color fondo = Color(0xFFFFFBFB);
  static const Color textoPrincipal = Color(0xFF241F20);
  static const Color textoSecundario = Color(0xFF6F6264);

  Map<String, dynamic> obtenerAnalisis() {
    final resultadoIa = mapaSeguro(resultado['resultado_ia']);
    if (resultadoIa.isNotEmpty) return resultadoIa;

    final analisis = mapaSeguro(resultado['analisis']);
    if (analisis.isNotEmpty) {
      final resultadoCompleto = mapaSeguro(analisis['resultado_completo']);
      if (resultadoCompleto.isNotEmpty) return resultadoCompleto;
      return analisis;
    }

    return resultado;
  }

  Map<String, dynamic> obtenerZonas(Map<String, dynamic> analisis) {
    final zonasAnalisis = analisis['zonas'];
    if (zonasAnalisis is Map) return mapaSeguro(zonasAnalisis);

    final zonasResultado = resultado['zonas'];
    if (zonasResultado is Map) return mapaSeguro(zonasResultado);

    if (zonasResultado is List) {
      final mapa = <String, dynamic>{};
      for (final item in zonasResultado) {
        final zona = mapaSeguro(item);
        final nombre = textoSeguro(zona['zona'], 'zona');
        final datosCompletos = mapaSeguro(zona['datos_completos']);
        mapa[nombre] = datosCompletos.isNotEmpty ? datosCompletos : zona;
      }
      return mapa;
    }

    return {};
  }

  Map<String, dynamic> obtenerRutina() {
    final recomendada = mapaSeguro(resultado['rutina_recomendada']);
    if (recomendada.isNotEmpty) return recomendada;

    final rutina = mapaSeguro(resultado['rutina']);
    if (rutina.isNotEmpty) {
      final rutinaCompleta = mapaSeguro(rutina['rutina_completa']);
      if (rutinaCompleta.isNotEmpty) return rutinaCompleta;
      return rutina;
    }

    final productos = listaMapas(resultado['productos']);
    if (productos.isNotEmpty) {
      final agrupada = <String, List<Map<String, dynamic>>>{
        'mañana': <Map<String, dynamic>>[],
        'día': <Map<String, dynamic>>[],
        'noche': <Map<String, dynamic>>[],
      };

      for (final producto in productos) {
        final momentoOriginal = textoSeguro(producto['momento']).toLowerCase();
        final momento = momentoOriginal.contains('noche')
            ? 'noche'
            : momentoOriginal.contains('dia') || momentoOriginal.contains('día')
                ? 'día'
                : 'mañana';
        agrupada[momento]!.add(producto);
      }

      return agrupada;
    }

    return {};
  }

  Map<String, dynamic> obtenerPuntajes(Map<String, dynamic> analisis) {
    final puntajes = mapaSeguro(analisis['puntajes']);
    if (puntajes.isNotEmpty) return puntajes;

    final puntajesResultado = mapaSeguro(resultado['puntajes']);
    if (puntajesResultado.isNotEmpty) return puntajesResultado;

    return {};
  }

  List<_MetricaPiel> construirMetricas(Map<String, dynamic> puntajes) {
    final metricas = <_MetricaPiel>[];

    final definiciones = <String, _DefinicionMetrica>{
      'manchas_generales': _DefinicionMetrica('Manchas', Icons.auto_awesome_outlined),
      'manchas_uv_estimadas': _DefinicionMetrica('Manchas estimadas', Icons.wb_sunny_outlined),
      'acne': _DefinicionMetrica('Brotes / acne', Icons.bubble_chart_outlined),
      'rojeces': _DefinicionMetrica('Rojeces', Icons.local_fire_department_outlined),
      'poros': _DefinicionMetrica('Poros', Icons.blur_on_outlined),
      'textura': _DefinicionMetrica('Textura', Icons.grain_outlined),
      'resequedad': _DefinicionMetrica('Resequedad', Icons.water_drop_outlined),
      'grasa': _DefinicionMetrica('Grasa', Icons.opacity_outlined),
      'ojeras': _DefinicionMetrica('Ojeras', Icons.remove_red_eye_outlined),
      'arrugas': _DefinicionMetrica('Lineas finas', Icons.timeline_outlined),
      'elasticidad': _DefinicionMetrica('Elasticidad', Icons.face_retouching_natural_outlined),
      'uniformidad_tono': _DefinicionMetrica('Tono desigual', Icons.palette_outlined),
    };

    for (final entrada in puntajes.entries) {
      final valor = numeroSeguro(entrada.value).clamp(0, 100).toDouble();
      final clave = entrada.key.toString();
      final definicion = definiciones[clave] ?? _DefinicionMetrica(_tituloDesdeClave(clave), Icons.spa_outlined);
      metricas.add(_MetricaPiel(clave: clave, titulo: definicion.titulo, valor: valor, icono: definicion.icono));
    }

    metricas.sort((a, b) => b.valor.compareTo(a.valor));
    return metricas;
  }

  int calcularEstadoGeneral(List<_MetricaPiel> metricas) {
    if (metricas.isEmpty) return 0;

    final utiles = metricas.where((m) => m.valor > 0).toList();
    final base = utiles.isEmpty ? metricas : utiles;
    final promedioProblema = base.map((m) => m.valor).reduce((a, b) => a + b) / base.length;
    return (100 - promedioProblema).clamp(0, 100).round();
  }

  String etiquetaEstadoGeneral(int puntaje) {
    if (puntaje >= 82) return 'Muy estable';
    if (puntaje >= 68) return 'Buen estado';
    if (puntaje >= 50) return 'Necesita apoyo';
    return 'Prioridad alta';
  }

  String resumenAmigable(Map<String, dynamic> analisis, List<_MetricaPiel> prioridades) {
    final resumenIa = textoSeguro(analisis['resumen_general'] ?? resultado['resumen_general']);
    if (resumenIa.isNotEmpty) return resumenIa;

    if (prioridades.isEmpty) {
      return 'Tu analisis esta listo. La app reviso las areas principales de la piel y preparo una rutina orientativa para ti.';
    }

    final nombres = prioridades.take(3).map((m) => m.titulo.toLowerCase()).toList();
    return 'Tu piel muestra como prioridad ${nombres.join(', ')}. El enfoque recomendado es mantener una rutina constante, suave y facil de seguir.';
  }

  String significadoParaCliente(List<_MetricaPiel> prioridades) {
    if (prioridades.isEmpty) {
      return 'No se detectaron areas destacadas en el analisis. Mantener una rutina constante y protector solar diario sigue siendo lo mas importante.';
    }

    final principal = prioridades.first;
    final nivel = principal.nivel.toLowerCase();

    if (principal.clave.contains('manchas') || principal.clave.contains('uniformidad')) {
      return 'La prioridad principal es el tono de la piel. Esto suele mejorar con constancia, proteccion solar diaria e ingredientes despigmentantes suaves.';
    }
    if (principal.clave.contains('acne')) {
      return 'Los brotes aparecen como prioridad $nivel. Conviene usar una rutina sencilla, evitar saturar la piel y elegir productos que no obstruyan los poros.';
    }
    if (principal.clave.contains('resequedad')) {
      return 'La piel parece necesitar mas apoyo de hidratacion y barrera. Esta semana conviene priorizar ingredientes calmantes y reparadores.';
    }
    if (principal.clave.contains('rojeces')) {
      return 'La piel muestra senales de sensibilidad o rojez. Lo mejor es calmar, hidratar y evitar activos fuertes por unos dias.';
    }
    if (principal.clave.contains('poros') || principal.clave.contains('textura')) {
      return 'La textura y los poros pueden mejorar con limpieza suave, hidratacion equilibrada y constancia. No hace falta una rutina agresiva.';
    }
    if (principal.clave.contains('arrugas') || principal.clave.contains('elasticidad')) {
      return 'La prioridad esta en firmeza y lineas finas. Conviene combinar hidratacion, protector solar y activos progresivos sin irritar la piel.';
    }

    return 'Tu piel necesita enfoque en ${principal.titulo.toLowerCase()}. La rutina recomendada esta pensada para trabajar ese punto sin saturar la piel.';
  }


  List<String> cosasAEvitar(List<_MetricaPiel> prioridades) {
    final evitar = <String>{};

    for (final metrica in prioridades.take(4)) {
      final clave = metrica.clave;
      if (clave.contains('rojeces') || clave.contains('resequedad')) {
        evitar.add('Exfoliantes fuertes si hay ardor o tirantez.');
        evitar.add('Retinol diario hasta que la piel este mas calmada.');
      }
      if (clave.contains('manchas') || clave.contains('uniformidad')) {
        evitar.add('Saltarte el protector solar durante el dia.');
      }
      if (clave.contains('acne')) {
        evitar.add('Usar demasiados productos nuevos al mismo tiempo.');
      }
      if (clave.contains('grasa') || clave.contains('poros')) {
        evitar.add('Limpiar la piel de forma agresiva o muy frecuente.');
      }
    }

    if (evitar.isEmpty) {
      evitar.add('Cambiar toda tu rutina de golpe.');
      evitar.add('Usar activos fuertes sin constancia ni proteccion solar.');
    }

    return evitar.take(4).toList();
  }

  List<String> recomendacionesGenerales(Map<String, dynamic> analisis) {
    final valor = analisis['recomendaciones_generales'];
    if (valor is List) {
      return valor.map((e) => textoSeguro(e)).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  String _tituloDesdeClave(String clave) {
    return clave.replaceAll('_', ' ').split(' ').where((p) => p.isNotEmpty).map((p) {
      return '${p[0].toUpperCase()}${p.length > 1 ? p.substring(1) : ''}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final analisis = obtenerAnalisis();
    final zonas = obtenerZonas(analisis);
    final rutina = obtenerRutina();
    final puntajes = obtenerPuntajes(analisis);
    final metricas = construirMetricas(puntajes);
    final prioridades = metricas.where((m) => m.valor >= 18).take(3).toList();
    final estadoGeneral = calcularEstadoGeneral(metricas);
    final resumen = resumenAmigable(analisis, prioridades);
    final significado = significadoParaCliente(prioridades);
    final evitar = cosasAEvitar(prioridades);
    final recomendaciones = recomendacionesGenerales(analisis);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Resultado de hoy'),
        backgroundColor: Colors.white,
        foregroundColor: textoPrincipal,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              _TarjetaHeroResultado(
                resumen: resumen,
                estadoGeneral: estadoGeneral,
                etiquetaEstado: etiquetaEstadoGeneral(estadoGeneral),
                prioridades: prioridades,
              ),
              const SizedBox(height: 10),
              _TarjetaQueSignifica(texto: significado),
              const SizedBox(height: 16),
              _TituloSeccionLimpio('Prioridades de tu piel', Icons.flag_outlined),
              if (prioridades.isEmpty)
                _TarjetaInfoSimple(
                  icono: Icons.check_circle_outline,
                  titulo: 'No hay una prioridad marcada',
                  texto: 'Tu piel se ve estable en las areas principales. Mantener la rutina y el protector solar sigue siendo clave.',
                )
              else
                ...prioridades.map((m) => _TarjetaPrioridad(metrica: m)),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Estado por area', Icons.bar_chart_rounded),
              _TarjetaMetricas(metricas: metricas),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Evita por ahora', Icons.do_not_disturb_on_outlined),
              _TarjetaLista(items: evitar),
              if (recomendaciones.isNotEmpty) ...[
                const SizedBox(height: 8),
                _TituloSeccionLimpio('Consejos de la IA', Icons.tips_and_updates_outlined),
                _TarjetaLista(items: recomendaciones.take(4).toList()),
              ],
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Rutina recomendada', Icons.spa_outlined),
              if (rutina.isEmpty)
                _TarjetaInfoSimple(
                  icono: Icons.spa_outlined,
                  titulo: 'Rutina no disponible',
                  texto: 'No se recibio una rutina recomendada para este analisis.',
                )
              else
                tarjetaRutina(rutina),
              const SizedBox(height: 8),
              _DetalleTecnico(metricas: metricas, zonas: zonas, analisis: analisis),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefinicionMetrica {
  final String titulo;
  final IconData icono;

  const _DefinicionMetrica(this.titulo, this.icono);
}

class _MetricaPiel {
  final String clave;
  final String titulo;

  /// Valor original que llega de la IA.
  /// En la API actual, 0 significa poco problema y 100 significa problema muy marcado.
  final double valor;
  final IconData icono;

  const _MetricaPiel({required this.clave, required this.titulo, required this.valor, required this.icono});

  /// Valor pensado para el cliente: mientras mas alto, mejor esta esa area.
  /// Ejemplo: si acne llega en 20 como problema, se muestra como 80 de estado.
  double get valorBueno => (100 - valor).clamp(0, 100).toDouble();

  String get nivel {
    if (valorBueno >= 82) return 'Muy bien';
    if (valorBueno >= 65) return 'Bien';
    if (valorBueno >= 45) return 'En progreso';
    return 'Necesita apoyo';
  }

  Color get color {
    if (valorBueno >= 82) return const Color(0xFF2E7D32);
    if (valorBueno >= 65) return const Color(0xFF5F8F2F);
    if (valorBueno >= 45) return const Color(0xFFB7791F);
    return const Color(0xFFDC1015);
  }

  String get explicacionCorta {
    if (valorBueno >= 82) return 'Se ve bajo control.';
    if (valorBueno >= 65) return 'Va en buen camino.';
    if (valorBueno >= 45) return 'Puede mejorar con constancia.';
    return 'Conviene darle prioridad.';
  }
}

class _TarjetaHeroResultado extends StatelessWidget {
  final String resumen;
  final int estadoGeneral;
  final String etiquetaEstado;
  final List<_MetricaPiel> prioridades;

  const _TarjetaHeroResultado({
    required this.resumen,
    required this.estadoGeneral,
    required this.etiquetaEstado,
    required this.prioridades,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF2DFE0)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IndicadorCircular(valor: estadoGeneral),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu piel hoy',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: PantallaResultadoAnalisis.textoPrincipal),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etiquetaEstado,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: PantallaResultadoAnalisis.rojoMarca),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Lectura orientativa basada en tu foto.',
                      style: TextStyle(color: PantallaResultadoAnalisis.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            resumen,
            style: const TextStyle(fontSize: 16, height: 1.45, color: PantallaResultadoAnalisis.textoPrincipal),
          ),
          if (prioridades.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prioridades.map((m) {
                return _ChipSuave(icono: m.icono, texto: '${m.titulo}: ${m.nivel}');
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _IndicadorCircular extends StatelessWidget {
  final int valor;

  const _IndicadorCircular({required this.valor});

  @override
  Widget build(BuildContext context) {
    final progreso = (valor / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: progreso,
              strokeWidth: 9,
              backgroundColor: const Color(0xFFF5E6E7),
              valueColor: const AlwaysStoppedAnimation<Color>(PantallaResultadoAnalisis.rojoMarca),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$valor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('/100', style: TextStyle(fontSize: 11, color: PantallaResultadoAnalisis.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaQueSignifica extends StatelessWidget {
  final String texto;

  const _TarjetaQueSignifica({required this.texto});

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconoRojo(icono: Icons.psychology_alt_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Que significa esto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(texto, style: const TextStyle(height: 1.45, color: PantallaResultadoAnalisis.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPrioridad extends StatelessWidget {
  final _MetricaPiel metrica;

  const _TarjetaPrioridad({required this.metrica});

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconoRojo(icono: metrica.icono),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metrica.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(metrica.explicacionCorta, style: const TextStyle(color: PantallaResultadoAnalisis.textoSecundario)),
                  ],
                ),
              ),
              _PildoraNivel(texto: metrica.nivel, color: metrica.color),
            ],
          ),
          const SizedBox(height: 14),
          _BarraMetrica(metrica: metrica, mostrarNumero: false),
        ],
      ),
    );
  }
}

class _TarjetaMetricas extends StatelessWidget {
  final List<_MetricaPiel> metricas;

  const _TarjetaMetricas({required this.metricas});

  @override
  Widget build(BuildContext context) {
    if (metricas.isEmpty) {
      return const _TarjetaInfoSimple(
        icono: Icons.bar_chart_rounded,
        titulo: 'Sin metricas disponibles',
        texto: 'La IA no envio puntajes suficientes para mostrar esta seccion.',
      );
    }

    return _CajaBlanca(
      child: Column(
        children: metricas.take(8).map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BarraMetrica(metrica: m, mostrarNumero: true),
          );
        }).toList(),
      ),
    );
  }
}

class _BarraMetrica extends StatelessWidget {
  final _MetricaPiel metrica;
  final bool mostrarNumero;

  const _BarraMetrica({required this.metrica, required this.mostrarNumero});

  @override
  Widget build(BuildContext context) {
    final valor = (metrica.valorBueno / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                metrica.titulo,
                style: const TextStyle(fontWeight: FontWeight.w800, color: PantallaResultadoAnalisis.textoPrincipal),
              ),
            ),
            Text(
              mostrarNumero ? '${metrica.nivel} · ${metrica.valorBueno.toStringAsFixed(0)}%' : metrica.nivel,
              style: TextStyle(fontWeight: FontWeight.w800, color: metrica.color),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: valor,
            minHeight: 9,
            backgroundColor: const Color(0xFFF4E8E8),
            valueColor: AlwaysStoppedAnimation<Color>(metrica.color),
          ),
        ),
      ],
    );
  }
}

class _TarjetaLista extends StatelessWidget {
  final List<String> items;

  const _TarjetaLista({required this.items});

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: PantallaResultadoAnalisis.rojoMarca, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: const TextStyle(height: 1.35))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DetalleTecnico extends StatelessWidget {
  final List<_MetricaPiel> metricas;
  final Map<String, dynamic> zonas;
  final Map<String, dynamic> analisis;

  const _DetalleTecnico({required this.metricas, required this.zonas, required this.analisis});

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: const Icon(Icons.analytics_outlined, color: PantallaResultadoAnalisis.rojoMarca),
          title: const Text('Ver detalle tecnico', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('Valores finales y zonas detectadas'),
          children: [
            if (metricas.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Metricas', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metricas.map((m) => Chip(label: Text('${m.titulo}: ${m.valorBueno.toStringAsFixed(0)}%'))).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (zonas.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Zonas', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              ...zonas.entries.map((entrada) {
                final zona = mapaSeguro(entrada.value);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECECEC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entrada.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(textoSeguro(zona['resumen'], 'Sin resumen disponible.'), style: const TextStyle(color: PantallaResultadoAnalisis.textoSecundario)),
                    ],
                  ),
                );
              }),
            ],
            if (textoSeguro(analisis['notas']).isNotEmpty)
              Text(textoSeguro(analisis['notas']), style: const TextStyle(color: PantallaResultadoAnalisis.textoSecundario)),
          ],
        ),
      ),
    );
  }
}

class _PildoraNivel extends StatelessWidget {
  final String texto;
  final Color color;

  const _PildoraNivel({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _ChipSuave extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _ChipSuave({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFF2D2D3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: PantallaResultadoAnalisis.rojoMarca),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconoRojo extends StatelessWidget {
  final IconData icono;

  const _IconoRojo({required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: const Color(0xFFFFEFEF), borderRadius: BorderRadius.circular(16)),
      child: Icon(icono, color: PantallaResultadoAnalisis.rojoMarca),
    );
  }
}

class _CajaBlanca extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const _CajaBlanca({required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E3E4)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _TituloSeccionLimpio extends StatelessWidget {
  final String texto;
  final IconData icono;

  const _TituloSeccionLimpio(this.texto, this.icono);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icono, color: PantallaResultadoAnalisis.rojoMarca, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _TarjetaInfoSimple extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;

  const _TarjetaInfoSimple({required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconoRojo(icono: icono),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(texto, style: const TextStyle(color: PantallaResultadoAnalisis.textoSecundario, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
