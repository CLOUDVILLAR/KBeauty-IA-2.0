import 'package:flutter/material.dart';

import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/tarjeta_rutina.dart';

class PantallaResultadoAnalisisExterno extends StatelessWidget {
  const PantallaResultadoAnalisisExterno({super.key, required this.datos});

  final Map<String, dynamic> datos;

  static const Color rojoMarca = Color(0xFFDC1015);
  static const Color fondo = Color(0xFFFFFBFB);
  static const Color textoPrincipal = Color(0xFF241F20);
  static const Color textoSecundario = Color(0xFF6F6264);
  static const String sinInfo = 'No se encontro informacion';

  Map<String, dynamic> get registro {
    final interno = mapaSeguro(datos['analisis_externo']);
    if (interno.isNotEmpty) return interno;
    return datos;
  }

  Map<String, dynamic> get analisis {
    final directo = mapaSeguro(datos['analisis_ia']);
    if (directo.isNotEmpty) return directo;
    return mapaSeguro(registro['analisis_ia']);
  }

  Map<String, dynamic> get rutinaRecomendada {
    final directa = mapaSeguro(datos['rutina_recomendada']);
    if (directa.isNotEmpty) return directa;
    return mapaSeguro(registro['rutina_recomendada']);
  }

  Map<String, dynamic> obtenerPuntajes() {
    final puntajes = mapaSeguro(analisis['puntajes']);
    if (puntajes.isNotEmpty) return puntajes;
    return mapaSeguro(mapaSeguro(registro['datos_extraidos'])['puntajes']);
  }

  List<Map<String, dynamic>> obtenerMetricasClave() {
    final metricas = listaMapas(analisis['metricas_clave']);
    if (metricas.isNotEmpty) return metricas;
    return listaMapas(mapaSeguro(registro['datos_extraidos'])['metricas_clave']);
  }

  List<String> obtenerLista(String clave) {
    final valor = analisis[clave];
    if (valor is List) return valor.map((e) => textoSeguro(e)).where((e) => e.isNotEmpty).toList();
    return <String>[];
  }

  String obtenerTexto(dynamic valor) => textoSeguro(valor, sinInfo);

  List<_MetricaExterna> construirMetricas(Map<String, dynamic> puntajes) {
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
      'hidratacion': _DefinicionMetrica('Hidratacion', Icons.water_drop_rounded),
    };

    final metricas = <_MetricaExterna>[];
    for (final entrada in puntajes.entries) {
      final clave = entrada.key.toString();
      final valorOriginal = entrada.value;
      final tieneValor = valorOriginal != null && textoSeguro(valorOriginal).toLowerCase() != 'n/d';
      final valor = tieneValor ? numeroSeguro(valorOriginal).clamp(0, 100).toDouble() : null;
      final definicion = definiciones[clave] ?? _DefinicionMetrica(_tituloDesdeClave(clave), Icons.spa_outlined);
      metricas.add(_MetricaExterna(clave: clave, titulo: definicion.titulo, valor: valor, icono: definicion.icono));
    }

    metricas.sort((a, b) => (b.valor ?? -1).compareTo(a.valor ?? -1));
    return metricas;
  }

  int? calcularEstadoGeneral(List<_MetricaExterna> metricas) {
    final conValor = metricas.where((m) => m.valor != null).toList();
    if (conValor.isEmpty) return null;
    final utiles = conValor.where((m) => (m.valor ?? 0) > 0).toList();
    final base = utiles.isEmpty ? conValor : utiles;
    final promedioProblema = base.map((m) => m.valor ?? 0).reduce((a, b) => a + b) / base.length;
    return (100 - promedioProblema).clamp(0, 100).round();
  }

  String etiquetaEstadoGeneral(int? puntaje) {
    if (puntaje == null) return sinInfo;
    if (puntaje >= 82) return 'Muy estable';
    if (puntaje >= 68) return 'Buen estado';
    if (puntaje >= 50) return 'Necesita apoyo';
    return 'Prioridad alta';
  }

  String _tituloDesdeClave(String clave) {
    return clave.replaceAll('_', ' ').split(' ').where((p) => p.isNotEmpty).map((p) {
      return '${p[0].toUpperCase()}${p.length > 1 ? p.substring(1) : ''}';
    }).join(' ');
  }

  String significadoParaCliente(List<_MetricaExterna> prioridades) {
    if (prioridades.isEmpty) return sinInfo;
    final principal = prioridades.first;
    if (principal.valor == null) return sinInfo;

    if (principal.clave.contains('manchas') || principal.clave.contains('uniformidad')) {
      return 'El analisis externo apunta al tono de la piel como prioridad. Conviene mantener protector solar diario y una rutina constante orientada a uniformidad.';
    }
    if (principal.clave.contains('acne')) {
      return 'El analisis externo sugiere brotes como punto a vigilar. Lo ideal es una rutina sencilla, no comedogenica y sin demasiados cambios al mismo tiempo.';
    }
    if (principal.clave.contains('resequedad') || principal.clave.contains('hidratacion')) {
      return 'La lectura externa sugiere trabajar hidratacion y barrera. La rutina recomendada prioriza reparar, calmar y sostener humedad.';
    }
    if (principal.clave.contains('rojeces')) {
      return 'La piel aparece con sensibilidad o rojez como prioridad. Conviene una rutina calmante y evitar activos fuertes mientras se estabiliza.';
    }
    if (principal.clave.contains('poros') || principal.clave.contains('textura')) {
      return 'Textura y poros aparecen como puntos relevantes. La recomendacion busca equilibrio sin limpiar ni exfoliar de forma agresiva.';
    }
    if (principal.clave.contains('arrugas') || principal.clave.contains('elasticidad')) {
      return 'El foco esta en firmeza y lineas finas. La rutina recomendada combina hidratacion, proteccion y activos progresivos.';
    }
    return 'El analisis externo marco ${principal.titulo.toLowerCase()} como prioridad. La rutina se eligio para trabajar ese punto sin saturar la piel.';
  }

  List<String> cosasAEvitar(List<_MetricaExterna> prioridades) {
    final evitar = <String>{};
    for (final metrica in prioridades.take(4)) {
      final clave = metrica.clave;
      if (clave.contains('rojeces') || clave.contains('resequedad') || clave.contains('hidratacion')) {
        evitar.add('Exfoliantes fuertes si hay ardor, tirantez o sensibilidad.');
        evitar.add('Retinol diario si la piel esta reactiva.');
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
    if (evitar.isEmpty) evitar.add(sinInfo);
    return evitar.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final puntajes = obtenerPuntajes();
    final metricas = construirMetricas(puntajes);
    final prioridades = metricas.where((m) => (m.valor ?? 0) >= 18).take(3).toList();
    final estadoGeneral = calcularEstadoGeneral(metricas);
    final resumen = obtenerTexto(analisis['resumen_general']);
    final significado = significadoParaCliente(prioridades);
    final recomendaciones = obtenerLista('recomendaciones_generales');
    final notas = obtenerLista('notas');
    final metricasClave = obtenerMetricasClave();
    final nombreArchivo = obtenerTexto(registro['nombre_archivo']);
    final proveedor = obtenerTexto(analisis['proveedor_detectado'] ?? registro['proveedor']);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Resultado externo'),
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
              _TarjetaHeroResultadoExterno(
                resumen: resumen,
                estadoGeneral: estadoGeneral,
                etiquetaEstado: etiquetaEstadoGeneral(estadoGeneral),
                prioridades: prioridades,
                proveedor: proveedor,
              ),
              const SizedBox(height: 10),
              _TarjetaQueSignifica(texto: significado),
              const SizedBox(height: 16),
              _TituloSeccionLimpio('Datos del PDF', Icons.picture_as_pdf_outlined),
              _TarjetaInfoPdf(nombreArchivo: nombreArchivo, proveedor: proveedor, fecha: fechaBonita(registro['creado_en'])),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Prioridades detectadas', Icons.flag_outlined),
              if (prioridades.isEmpty)
                const _TarjetaInfoSimple(
                  icono: Icons.search_off_rounded,
                  titulo: 'No se encontro informacion',
                  texto: 'El PDF no trajo datos suficientes para marcar prioridades claras en este punto.',
                )
              else
                ...prioridades.map((m) => _TarjetaPrioridad(metrica: m)),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Estado por area', Icons.bar_chart_rounded),
              _TarjetaMetricas(metricas: metricas),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Metricas del equipo', Icons.analytics_outlined),
              _TarjetaMetricasClave(metricas: metricasClave),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Evita por ahora', Icons.do_not_disturb_on_outlined),
              _TarjetaLista(items: cosasAEvitar(prioridades)),
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Consejos de la IA', Icons.tips_and_updates_outlined),
              _TarjetaLista(items: recomendaciones.isEmpty ? const [sinInfo] : recomendaciones.take(4).toList()),
              if (notas.isNotEmpty) ...[
                const SizedBox(height: 8),
                _TituloSeccionLimpio('Notas del PDF', Icons.info_outline_rounded),
                _TarjetaLista(items: notas.take(4).toList()),
              ],
              const SizedBox(height: 8),
              _TituloSeccionLimpio('Rutina recomendada', Icons.spa_outlined),
              _TarjetaRutinaSeleccionada(rutina: rutinaRecomendada),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefinicionMetrica {
  const _DefinicionMetrica(this.titulo, this.icono);
  final String titulo;
  final IconData icono;
}

class _MetricaExterna {
  const _MetricaExterna({required this.clave, required this.titulo, required this.valor, required this.icono});

  final String clave;
  final String titulo;
  final double? valor;
  final IconData icono;

  double? get valorBueno => valor == null ? null : (100 - valor!).clamp(0, 100).toDouble();

  String get nivel {
    final bueno = valorBueno;
    if (bueno == null) return PantallaResultadoAnalisisExterno.sinInfo;
    if (bueno >= 82) return 'Muy bien';
    if (bueno >= 65) return 'Bien';
    if (bueno >= 45) return 'En progreso';
    return 'Necesita apoyo';
  }

  Color get color {
    final bueno = valorBueno;
    if (bueno == null) return PantallaResultadoAnalisisExterno.textoSecundario;
    if (bueno >= 82) return const Color(0xFF2E7D32);
    if (bueno >= 65) return const Color(0xFF5F8F2F);
    if (bueno >= 45) return const Color(0xFFB7791F);
    return const Color(0xFFDC1015);
  }

  String get explicacionCorta {
    final bueno = valorBueno;
    if (bueno == null) return PantallaResultadoAnalisisExterno.sinInfo;
    if (bueno >= 82) return 'Se ve bajo control.';
    if (bueno >= 65) return 'Va en buen camino.';
    if (bueno >= 45) return 'Puede mejorar con constancia.';
    return 'Conviene darle prioridad.';
  }
}

class _TarjetaHeroResultadoExterno extends StatelessWidget {
  const _TarjetaHeroResultadoExterno({required this.resumen, required this.estadoGeneral, required this.etiquetaEstado, required this.prioridades, required this.proveedor});

  final String resumen;
  final int? estadoGeneral;
  final String etiquetaEstado;
  final List<_MetricaExterna> prioridades;
  final String proveedor;

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
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
                    const Text('Tu analisis externo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: PantallaResultadoAnalisisExterno.textoPrincipal)),
                    const SizedBox(height: 4),
                    Text(etiquetaEstado, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: PantallaResultadoAnalisisExterno.rojoMarca)),
                    const SizedBox(height: 6),
                    const Text('Lectura orientativa basada en PDF externo.', style: TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(resumen, style: const TextStyle(fontSize: 16, height: 1.45, color: PantallaResultadoAnalisisExterno.textoPrincipal)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipSuave(icono: Icons.picture_as_pdf_outlined, texto: 'Fuente externa'),
              _ChipSuave(icono: Icons.precision_manufacturing_outlined, texto: proveedor),
              ...prioridades.map((m) => _ChipSuave(icono: m.icono, texto: '${m.titulo}: ${m.nivel}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicadorCircular extends StatelessWidget {
  const _IndicadorCircular({required this.valor});
  final int? valor;

  @override
  Widget build(BuildContext context) {
    final progreso = ((valor ?? 0) / 100).clamp(0.0, 1.0);
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
              value: valor == null ? 0.0 : progreso,
              strokeWidth: 9,
              backgroundColor: const Color(0xFFF5E6E7),
              valueColor: const AlwaysStoppedAnimation<Color>(PantallaResultadoAnalisisExterno.rojoMarca),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valor == null ? 'N/D' : '$valor', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('/100', style: TextStyle(fontSize: 11, color: PantallaResultadoAnalisisExterno.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaQueSignifica extends StatelessWidget {
  const _TarjetaQueSignifica({required this.texto});
  final String texto;

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
                Text(texto, style: const TextStyle(height: 1.45, color: PantallaResultadoAnalisisExterno.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaInfoPdf extends StatelessWidget {
  const _TarjetaInfoPdf({required this.nombreArchivo, required this.proveedor, required this.fecha});
  final String nombreArchivo;
  final String proveedor;
  final String fecha;

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      child: Column(
        children: [
          _FilaDato(icono: Icons.description_outlined, titulo: 'Archivo', valor: nombreArchivo),
          const Divider(height: 22, color: KBeautyColors.borde),
          _FilaDato(icono: Icons.precision_manufacturing_outlined, titulo: 'Equipo / proveedor', valor: proveedor),
          const Divider(height: 22, color: KBeautyColors.borde),
          _FilaDato(icono: Icons.event_outlined, titulo: 'Fecha importada', valor: textoSeguro(fecha, PantallaResultadoAnalisisExterno.sinInfo)),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.titulo, required this.valor});
  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconoRojo(icono: icono),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(valor, style: const TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaPrioridad extends StatelessWidget {
  const _TarjetaPrioridad({required this.metrica});
  final _MetricaExterna metrica;

  @override
  Widget build(BuildContext context) {
    return _CajaBlanca(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _IconoRojo(icono: metrica.icono),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metrica.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text(metrica.explicacionCorta, style: const TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario)),
              ],
            ),
          ),
          _PildoraNivel(texto: metrica.nivel, color: metrica.color),
        ],
      ),
    );
  }
}

class _TarjetaMetricas extends StatelessWidget {
  const _TarjetaMetricas({required this.metricas});
  final List<_MetricaExterna> metricas;

  @override
  Widget build(BuildContext context) {
    if (metricas.isEmpty) {
      return const _TarjetaInfoSimple(icono: Icons.search_off_rounded, titulo: 'No se encontro informacion', texto: 'El PDF no trajo puntajes comparables para mostrar en esta seccion.');
    }
    return _CajaBlanca(
      child: Column(
        children: metricas.map((metrica) => _FilaMetricaEstado(metrica: metrica)).toList(),
      ),
    );
  }
}

class _FilaMetricaEstado extends StatelessWidget {
  const _FilaMetricaEstado({required this.metrica});
  final _MetricaExterna metrica;

  @override
  Widget build(BuildContext context) {
    final valorBueno = metrica.valorBueno;
    final progreso = ((valorBueno ?? 0) / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metrica.icono, color: metrica.color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(metrica.titulo, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(valorBueno == null ? 'N/D' : '${valorBueno.round()}/100', style: TextStyle(color: metrica.color, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: valorBueno == null ? 0.0 : progreso,
              minHeight: 9,
              backgroundColor: const Color(0xFFF5E6E7),
              valueColor: AlwaysStoppedAnimation<Color>(metrica.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetricasClave extends StatelessWidget {
  const _TarjetaMetricasClave({required this.metricas});
  final List<Map<String, dynamic>> metricas;

  @override
  Widget build(BuildContext context) {
    if (metricas.isEmpty) {
      return const _TarjetaInfoSimple(icono: Icons.search_off_rounded, titulo: 'No se encontro informacion', texto: 'El PDF no incluyo metricas numericas o interpretaciones claras para esta seccion.');
    }
    return _CajaBlanca(
      child: Column(
        children: metricas.take(10).map((m) {
          final nombre = textoSeguro(m['nombre'], PantallaResultadoAnalisisExterno.sinInfo);
          final valor = textoSeguro(m['valor'], 'N/D');
          final unidad = textoSeguro(m['unidad']);
          final interpretacion = textoSeguro(m['interpretacion'], PantallaResultadoAnalisisExterno.sinInfo);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KBeautyColors.rosaMuySuave,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: KBeautyColors.borde),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(interpretacion, style: const TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('$valor$unidad', style: const TextStyle(color: PantallaResultadoAnalisisExterno.rojoMarca, fontWeight: FontWeight.w900)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TarjetaRutinaSeleccionada extends StatelessWidget {
  const _TarjetaRutinaSeleccionada({required this.rutina});
  final Map<String, dynamic> rutina;

  @override
  Widget build(BuildContext context) {
    if (rutina.isEmpty) {
      return const _TarjetaInfoSimple(icono: Icons.spa_outlined, titulo: 'No se encontro informacion', texto: 'No se pudo asignar una rutina a este PDF.');
    }
    final nombre = textoSeguro(rutina['nombre_rutina'], PantallaResultadoAnalisisExterno.sinInfo);
    final razon = textoSeguro(rutina['razon_rutina'], PantallaResultadoAnalisisExterno.sinInfo);
    final rutinaBase = mapaSeguro(rutina['rutina']).isNotEmpty ? mapaSeguro(rutina['rutina']) : rutina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CajaBlanca(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconoRojo(icono: Icons.spa_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: PantallaResultadoAnalisisExterno.rojoMarca)),
                    const SizedBox(height: 8),
                    Text(razon, style: const TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario, height: 1.35, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        tarjetaRutina(rutinaBase, unirMananaConDia: true),
      ],
    );
  }
}

class _TarjetaLista extends StatelessWidget {
  const _TarjetaLista({required this.items});
  final List<String> items;

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
                const Icon(Icons.check_circle_outline, color: PantallaResultadoAnalisisExterno.rojoMarca, size: 21),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: const TextStyle(height: 1.35, fontWeight: FontWeight.w700))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TarjetaInfoSimple extends StatelessWidget {
  const _TarjetaInfoSimple({required this.icono, required this.titulo, required this.texto});
  final IconData icono;
  final String titulo;
  final String texto;

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
                Text(texto, style: const TextStyle(color: PantallaResultadoAnalisisExterno.textoSecundario, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CajaBlanca extends StatelessWidget {
  const _CajaBlanca({required this.child, this.margin});
  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF2DFE0)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _TituloSeccionLimpio extends StatelessWidget {
  const _TituloSeccionLimpio(this.texto, this.icono);
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      child: Row(
        children: [
          _IconoRojo(icono: icono, pequeno: true),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: PantallaResultadoAnalisisExterno.textoPrincipal))),
        ],
      ),
    );
  }
}

class _IconoRojo extends StatelessWidget {
  const _IconoRojo({required this.icono, this.pequeno = false});
  final IconData icono;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: pequeno ? 34 : 44,
      height: pequeno ? 34 : 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EA),
        borderRadius: BorderRadius.circular(pequeno ? 14 : 16),
      ),
      child: Icon(icono, color: PantallaResultadoAnalisisExterno.rojoMarca, size: pequeno ? 19 : 23),
    );
  }
}

class _ChipSuave extends StatelessWidget {
  const _ChipSuave({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFCDD0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: PantallaResultadoAnalisisExterno.rojoMarca),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(color: PantallaResultadoAnalisisExterno.rojoMarca, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PildoraNivel extends StatelessWidget {
  const _PildoraNivel({required this.texto, required this.color});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}
