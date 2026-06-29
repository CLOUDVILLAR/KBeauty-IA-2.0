import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../servicios/servicio_analisis_externo.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis_externo.dart';

class PantallaAnalisisExterno extends StatefulWidget {
  const PantallaAnalisisExterno({super.key});

  @override
  State<PantallaAnalisisExterno> createState() => _PantallaAnalisisExternoState();
}

class _PantallaAnalisisExternoState extends State<PantallaAnalisisExterno> {
  File? pdfSeleccionado;
  bool importando = false;
  late Future<List<Map<String, dynamic>>> futuroHistorial;

  @override
  void initState() {
    super.initState();
    futuroHistorial = obtenerHistorialAnalisisExterno();
  }

  Future<void> seleccionarPdf() async {
    if (importando) return;
    const grupoPdf = XTypeGroup(
      label: 'PDF',
      extensions: <String>['pdf'],
      mimeTypes: <String>['application/pdf'],
    );

    final archivo = await openFile(acceptedTypeGroups: <XTypeGroup>[grupoPdf]);
    final ruta = archivo?.path;
    if (ruta == null || ruta.isEmpty) return;

    setState(() => pdfSeleccionado = File(ruta));
  }

  Future<void> importar() async {
    final pdf = pdfSeleccionado;
    if (pdf == null) {
      mostrarMensaje(context, 'Selecciona un PDF de analisis externo primero.');
      return;
    }

    setState(() => importando = true);
    try {
      final respuesta = await importarAnalisisExternoPdf(pdf);
      if (!mounted) return;
      final datos = Map<String, dynamic>.from(respuesta['datos'] as Map);
      setState(() {
        pdfSeleccionado = null;
        futuroHistorial = obtenerHistorialAnalisisExterno();
      });
      mostrarMensaje(context, 'Analisis externo importado correctamente.');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisisExterno(datos: datos),
        ),
      );
      if (mounted) setState(() => futuroHistorial = obtenerHistorialAnalisisExterno());
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => importando = false);
    }
  }

  Future<void> abrirHistorial(Map<String, dynamic> item) async {
    final id = textoSeguro(item['id']);
    if (id.isEmpty) return;

    try {
      final detalle = await obtenerDetalleAnalisisExterno(id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisisExterno(datos: detalle),
        ),
      );
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KBeautyColors.fondo,
      appBar: AppBar(title: const Text('Importar analisis externo')),
      body: SafeArea(
        child: centrarContenido(
          context,
          RefreshIndicator(
            onRefresh: () async {
              setState(() => futuroHistorial = obtenerHistorialAnalisisExterno());
              await futuroHistorial;
            },
            child: ListView(
              padding: margenPantalla(context),
              children: [
                tarjetaGradiente(
                  hijo: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 34),
                      SizedBox(height: 12),
                      Text(
                        'Importar analisis externo',
                        style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sube el PDF de la maquina facial. KBeauty IA lo interpreta y crea un resultado separado de tu evolucion principal.',
                        style: TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                tarjetaBase(
                  hijo: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PDF del analisis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                        pdfSeleccionado == null ? 'No has seleccionado ningun archivo.' : pdfSeleccionado!.path.split(Platform.pathSeparator).last,
                        style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: importando ? null : seleccionarPdf,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: const Text('Elegir PDF'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: importando ? null : importar,
                              icon: importando
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: Text(importando ? 'Analizando...' : 'Importar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                tituloSeccion('Historial externo', icono: Icons.folder_copy_rounded, subtitulo: 'Cada PDF tiene su propia vista de resultado'),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: futuroHistorial,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return cargandoCentro('Cargando historial externo...');
                    }
                    if (snapshot.hasError) {
                      return mensajeError(snapshot.error.toString(), alReintentar: () {
                        setState(() => futuroHistorial = obtenerHistorialAnalisisExterno());
                      });
                    }
                    final historial = snapshot.data ?? <Map<String, dynamic>>[];
                    if (historial.isEmpty) {
                      return tarjetaSuave(
                        hijo: const Text(
                          'Aun no hay PDFs externos importados.',
                          style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700),
                        ),
                      );
                    }
                    return Column(
                      children: historial.map((item) => _TarjetaHistorialExterno(item: item, onTap: () => abrirHistorial(item))).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaHistorialExterno extends StatelessWidget {
  const _TarjetaHistorialExterno({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final analisis = mapaSeguro(item['analisis_ia']);
    final rutina = mapaSeguro(item['rutina_recomendada']);
    final resumen = textoSeguro(analisis['resumen_general'], 'No se encontro informacion');
    final rutinaNombre = textoSeguro(rutina['nombre_rutina'], 'No se encontro informacion');
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: tarjetaBase(
        relleno: const EdgeInsets.all(16),
        hijo: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: KBeautyColors.rojoSuave, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: KBeautyColors.rojo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(textoSeguro(item['nombre_archivo'], 'Analisis externo'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(fechaBonita(item['creado_en']), style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: KBeautyColors.rojo),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              resumen,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.3, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            chipSuave(rutinaNombre, icono: Icons.spa_rounded),
          ],
        ),
      ),
    );
  }
}
