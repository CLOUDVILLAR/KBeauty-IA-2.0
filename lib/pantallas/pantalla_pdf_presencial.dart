import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../servicios/servicio_analisis.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';

class PantallaPdfPresencial extends StatefulWidget {
  const PantallaPdfPresencial({super.key, required this.analisis});

  final Map<String, dynamic> analisis;

  @override
  State<PantallaPdfPresencial> createState() => _PantallaPdfPresencialState();
}

class _PantallaPdfPresencialState extends State<PantallaPdfPresencial> {
  late Future<File> _futuroPdf;
  late final PdfViewerController _controladorPdf;

  @override
  void initState() {
    super.initState();
    _controladorPdf = PdfViewerController();
    _futuroPdf = _descargarPdf();
  }

  String get _idAnalisis => textoSeguro(widget.analisis['id']);

  String get _titulo {
    final titulo = textoSeguro(widget.analisis['titulo']);
    return titulo.isEmpty ? 'Análisis presencial' : titulo;
  }

  String get _fecha {
    final fecha = fechaBonita(
      widget.analisis['creado_en'] ?? widget.analisis['fecha'] ?? widget.analisis['created_at'],
    );
    return fecha.isEmpty ? 'Fecha no disponible' : fecha;
  }

  Future<File> _descargarPdf() {
    return descargarPdfAnalisisPresencial(_idAnalisis);
  }

  Future<void> _recargar() async {
    setState(() => _futuroPdf = _descargarPdf());
  }

  @override
  Widget build(BuildContext context) {
    final nombreArchivo = textoSeguro(widget.analisis['archivo_nombre']);

    return Scaffold(
      backgroundColor: KBeautyColors.rosaMuySuave,
      appBar: AppBar(
        title: const Text('PDF presencial'),
        backgroundColor: KBeautyColors.rosaMuySuave,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            centrarContenido(
              context,
              Padding(
                padding: margenPantalla(context).copyWith(bottom: 10),
                child: tarjetaGradiente(
                  hijo: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(.22)),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              nombreArchivo.isEmpty ? _fecha : '$nombreArchivo · $_fecha',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(.88), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: centrarContenido(
                context,
                Padding(
                  padding: margenPantalla(context).copyWith(top: 0),
                  child: tarjetaBase(
                    relleno: EdgeInsets.zero,
                    hijo: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: FutureBuilder<File>(
                        future: _futuroPdf,
                        builder: (context, snapshot) {
                          if (_idAnalisis.isEmpty) {
                            return mensajeError('No se encontró el ID del análisis presencial.');
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return cargandoCentro('Descargando PDF...');
                          }

                          if (snapshot.hasError) {
                            return mensajeError(
                              snapshot.error.toString(),
                              alReintentar: _recargar,
                            );
                          }

                          final archivo = snapshot.data;
                          if (archivo == null || !archivo.existsSync()) {
                            return mensajeError('No se pudo preparar el PDF en el teléfono.', alReintentar: _recargar);
                          }

                          return SfPdfViewer.file(
                            archivo,
                            controller: _controladorPdf,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                            enableDoubleTapZooming: true,
                            onDocumentLoadFailed: (details) {
                              mostrarMensaje(context, 'No se pudo cargar el PDF: ${details.description}');
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
