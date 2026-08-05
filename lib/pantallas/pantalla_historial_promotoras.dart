import 'package:flutter/material.dart';

import '../servicios/servicio_promotoras.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

/// Historial de los analisis hechos por promotoras (clientes walk-in). Cada
/// tarjeta muestra nombre y telefono del cliente, para poder identificarlo
/// sin depender de una cuenta con sesion iniciada.
class PantallaHistorialPromotoras extends StatefulWidget {
  const PantallaHistorialPromotoras({super.key});

  @override
  State<PantallaHistorialPromotoras> createState() => _PantallaHistorialPromotorasState();
}

class _PantallaHistorialPromotorasState extends State<PantallaHistorialPromotoras> {
  late Future<List<Map<String, dynamic>>> futuro;

  @override
  void initState() {
    super.initState();
    futuro = obtenerHistorialPromotoras();
  }

  Future<void> _recargar() async {
    setState(() => futuro = obtenerHistorialPromotoras());
    await futuro;
  }

  Future<void> _abrirDetalle(Map<String, dynamic> item) async {
    final id = textoSeguro(item['id']);
    if (id.isEmpty) return;

    try {
      final detalle = await obtenerDetalleHistorialPromotora(id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisis(
            resultado: detalle,
            clienteNombre: textoSeguro(item['cliente_nombre']),
            clienteTelefono: textoSeguro(item['cliente_telefono']),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo abrir el analisis: $error');
      }
    }
  }

  String _condicion(Map<String, dynamic> item) {
    final condicion = textoSeguro(item['condicion_principal_detectada']);
    final tipoPiel = textoSeguro(item['tono_piel']);
    if (condicion.isNotEmpty && condicion.toLowerCase() != 'none') {
      return tipoPiel.isEmpty ? condicion : '$tipoPiel · $condicion';
    }
    return tipoPiel.isEmpty ? 'Sin condicion detectada' : tipoPiel;
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
              'No se pudo cargar el historial: ${snapshot.error}',
              alReintentar: _recargar,
            );
          }

          final datos = snapshot.data ?? [];

          if (datos.isEmpty) {
            return _HistorialVacio(onRetry: _recargar);
          }

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _recargar,
              color: KBeautyColors.rojo,
              child: centrarContenido(
                context,
                ListView(
                  padding: margenPantalla(context),
                  children: datos
                      .map(
                        (item) => InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _abrirDetalle(item),
                          child: tarjetaBase(
                            hijo: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: KBeautyColors.rojoSuave,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.person_outline, color: KBeautyColors.rojo),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        textoSeguro(item['cliente_nombre'], 'Cliente sin nombre'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        textoSeguro(item['cliente_telefono'], 'Sin telefono'),
                                        style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _condicion(item),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fechaBonita(item['creado_en']),
                                        style: const TextStyle(color: KBeautyColors.textoSuave, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: KBeautyColors.textoSuave),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
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
                    'Aun no hay analisis guardados',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuando guardes el analisis de un cliente, aparecera aqui.',
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
