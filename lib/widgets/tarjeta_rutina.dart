import 'package:flutter/material.dart';

import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import 'tarjeta_base.dart';
import 'tarjeta_producto.dart';

Widget tarjetaRutina(
  Map<String, dynamic> rutina, {
  bool unirMananaConDia = false,
}) {
  final bloques = unirMananaConDia
      ? <_MomentoRutina>[
          const _MomentoRutina(
            clave: 'día',
            titulo: 'Día',
            subtitulo: 'Une los pasos de mañana y día en el mismo orden.',
            icono: Icons.wb_sunny_rounded,
            color: KBeautyColors.rojo,
          ),
          const _MomentoRutina(
            clave: 'noche',
            titulo: 'Noche',
            subtitulo: 'Repara, calma y trata mientras descansas.',
            icono: Icons.nights_stay_rounded,
            color: Color(0xFF7C3AED),
          ),
        ]
      : <_MomentoRutina>[
          const _MomentoRutina(
            clave: 'mañana',
            titulo: 'Mañana',
            subtitulo: 'Protege y prepara la piel para el día.',
            icono: Icons.wb_sunny_rounded,
            color: Color(0xFFF59E0B),
          ),
          const _MomentoRutina(
            clave: 'día',
            titulo: 'Durante el día',
            subtitulo: 'Mantén hidratación y protección.',
            icono: Icons.brightness_5_rounded,
            color: KBeautyColors.rojo,
          ),
          const _MomentoRutina(
            clave: 'noche',
            titulo: 'Noche',
            subtitulo: 'Repara, calma y trata mientras descansas.',
            icono: Icons.nights_stay_rounded,
            color: Color(0xFF7C3AED),
          ),
        ];

  final contenedor = mapaSeguro(rutina['rutina_completa'] ?? rutina['rutina'] ?? rutina);
  final momentos = mapaSeguro(contenedor['rutina'] ?? contenedor);

  final tarjetas = <Widget>[];

  for (final momento in bloques) {
    final productos = unirMananaConDia && momento.clave == 'día'
        ? <Map<String, dynamic>>[
            ...listaMapas(momentos['mañana'] ?? momentos['manana'] ?? rutina['mañana'] ?? rutina['manana']),
            ...listaMapas(momentos['día'] ?? momentos['dia'] ?? rutina['día'] ?? rutina['dia']),
          ]
        : listaMapas(momentos[momento.clave] ?? rutina[momento.clave]);
    if (productos.isEmpty) continue;

    tarjetas.add(
      _TarjetaMomentoRutina(
        momento: momento,
        productos: productos,
      ),
    );
  }

  if (tarjetas.isEmpty) {
    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: KBeautyColors.rojoSuave,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.spa_rounded, color: KBeautyColors.rojo),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aún no hay rutina recomendada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Realiza un análisis de piel para que la IA prepare una rutina clara y personalizada.',
            style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.35),
          ),
        ],
      ),
    );
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tarjetas);
}

class _MomentoRutina {
  const _MomentoRutina({
    required this.clave,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
  });

  final String clave;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
}

class _TarjetaMomentoRutina extends StatelessWidget {
  const _TarjetaMomentoRutina({required this.momento, required this.productos});

  final _MomentoRutina momento;
  final List<Map<String, dynamic>> productos;

  @override
  Widget build(BuildContext context) {
    return tarjetaBase(
      relleno: const EdgeInsets.all(0),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: momento.color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(momento.icono, color: momento.color, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(momento.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(momento.subtitulo, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.25)),
                    ],
                  ),
                ),
                chipSuave('${productos.length}', icono: Icons.check_rounded, color: momento.color),
              ],
            ),
          ),
          const Divider(height: 1, color: KBeautyColors.borde),
          ...productos.asMap().entries.map(
            (entrada) => _PasoRutina(
              numero: entrada.key + 1,
              momento: momento,
              producto: entrada.value,
              esUltimo: entrada.key == productos.length - 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoRutina extends StatelessWidget {
  const _PasoRutina({required this.numero, required this.momento, required this.producto, required this.esUltimo});

  final int numero;
  final _MomentoRutina momento;
  final Map<String, dynamic> producto;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final nombre = textoSeguro(producto['nombre_producto'] ?? producto['nombre'] ?? producto['producto'], 'Producto');
    final categoria = textoSeguro(producto['categoria'], 'Producto recomendado');
    final subtipo = textoSeguro(producto['subtipo']);
    final frecuencia = textoSeguro(producto['frecuencia']);
    final uso = _textoUsoProducto(producto, momento.clave);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: esUltimo ? Colors.transparent : KBeautyColors.borde),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: momento.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    numero.toString(),
                    style: TextStyle(color: momento.color, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.15)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chipSuave(subtipo.isEmpty ? categoria : subtipo, icono: Icons.spa_outlined, color: momento.color),
                        if (frecuencia.isNotEmpty) chipSuave(frecuencia, icono: Icons.repeat_rounded, color: const Color(0xFF0EA5E9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (uso.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KBeautyColors.rosaMuySuave,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: KBeautyColors.borde),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_rounded, size: 20, color: momento.color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      uso,
                      style: const TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Ver detalle del producto', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              subtitle: const Text('Ubicación, ID y disponibilidad si aplica', style: TextStyle(color: KBeautyColors.textoSuave, fontSize: 12)),
              trailing: const Icon(Icons.keyboard_arrow_down_rounded),
              children: [
                const SizedBox(height: 8),
                tarjetaProducto(producto),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _textoUsoProducto(Map<String, dynamic> producto, String momento) {
    final descripcion = mapaSeguro(producto['descripcion_rutina']);

    final textoDescripcion = textoSeguro(
      descripcion[momento] ?? descripcion['día'] ?? descripcion['mañana'] ?? descripcion['noche'],
    );
    if (textoDescripcion.isNotEmpty) return textoDescripcion;

    final uso = producto['uso'];
    if (uso is Map) {
      final usoMapa = mapaSeguro(uso);
      return textoSeguro(
        usoMapa[momento] ?? usoMapa['paso_rutina'] ?? usoMapa['modo_uso'] ?? usoMapa['descripcion'] ?? usoMapa['texto'],
      );
    }

    return textoSeguro(uso ?? producto['modo_uso'] ?? producto['instrucciones']);
  }
}
