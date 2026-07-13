import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../widgets/silueta_cara.dart';

/// Camara propia con la silueta guia dibujada en tiempo real sobre la vista
/// previa. Devuelve el [File] de la foto tomada, o null si se cancela.
/// [indice]: 0 = frente, 1 = lado izquierdo, 2 = lado derecho.
class PantallaCamaraGuiada extends StatefulWidget {
  const PantallaCamaraGuiada({super.key, required this.indice});

  final int indice;

  static const titulos = ['Frente', 'Lado izquierdo', 'Lado derecho'];

  @override
  State<PantallaCamaraGuiada> createState() => _PantallaCamaraGuiadaState();
}

class _PantallaCamaraGuiadaState extends State<PantallaCamaraGuiada>
    with WidgetsBindingObserver {
  CameraController? controlador;
  List<CameraDescription> camaras = [];
  int indiceCamara = -1;
  bool inicializando = true;
  bool capturando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controlador?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final actual = controlador;
    if (actual == null || !actual.value.isInitialized) return;
    if (estado == AppLifecycleState.inactive) {
      actual.dispose();
      controlador = null;
    } else if (estado == AppLifecycleState.resumed && indiceCamara >= 0) {
      _abrirCamara(indiceCamara);
    }
  }

  Future<void> _iniciar() async {
    try {
      camaras = await availableCameras();
      if (camaras.isEmpty) {
        error = 'No se encontró ninguna cámara en el dispositivo.';
      } else {
        // La camara frontal es la mas comoda para autofotos del rostro.
        var frontal = camaras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontal < 0) frontal = 0;
        await _abrirCamara(frontal);
      }
    } catch (_) {
      error = 'No se pudo abrir la cámara. Revisa el permiso de cámara de la app.';
    }
    if (mounted) setState(() => inicializando = false);
  }

  Future<void> _abrirCamara(int indice) async {
    final anterior = controlador;
    controlador = null;
    if (mounted) setState(() => inicializando = true);
    await anterior?.dispose();

    final nuevo = CameraController(
      camaras[indice],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await nuevo.initialize();
      indiceCamara = indice;
      controlador = nuevo;
      error = null;
    } on CameraException {
      error = 'No se pudo abrir la cámara. Revisa el permiso de cámara de la app.';
    }
    if (mounted) setState(() => inicializando = false);
  }

  Future<void> _cambiarCamara() async {
    if (camaras.length < 2 || inicializando || capturando) return;
    await _abrirCamara((indiceCamara + 1) % camaras.length);
  }

  Future<void> _capturar() async {
    final actual = controlador;
    if (actual == null || !actual.value.isInitialized || capturando) return;

    setState(() => capturando = true);
    try {
      final foto = await actual.takePicture();
      if (mounted) Navigator.of(context).pop(File(foto.path));
    } catch (_) {
      if (mounted) {
        setState(() => capturando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo tomar la foto. Inténtalo de nuevo.')),
        );
      }
    }
  }

  Widget _vistaCamara() {
    final actual = controlador;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (inicializando || actual == null || !actual.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // La vista previa llega en horizontal: se invierte para retrato y se
    // recorta para llenar la pantalla completa.
    final tamanoPreview = actual.value.previewSize!;
    return LayoutBuilder(
      builder: (_, restricciones) => ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: tamanoPreview.height,
              height: tamanoPreview.width,
              child: CameraPreview(actual),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listo = controlador != null &&
        controlador!.value.isInitialized &&
        !inicializando &&
        error == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _vistaCamara(),
            // Silueta guia en rojo sobre la camara en vivo.
            if (listo)
              IgnorePointer(
                child: CustomPaint(
                  painter: PintorSiluetaCara(
                    indice: widget.indice,
                    color: const Color(0xFFE53935),
                    grosor: 3.5,
                  ),
                ),
              ),
            // Barra superior: cerrar + titulo.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.black45,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: capturando ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        'Foto ${widget.indice + 1} de 3: ${PantallaCamaraGuiada.titulos[widget.indice]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            // Controles inferiores: cambiar camara + boton de captura.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Colors.black45,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ajusta tu cara dentro de la silueta y toma la foto',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 64),
                        GestureDetector(
                          onTap: listo && !capturando ? _capturar : null,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: capturando ? Colors.white38 : Colors.white24,
                            ),
                            child: capturando
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 34),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: camaras.length > 1
                              ? IconButton(
                                  onPressed: capturando ? null : _cambiarCamara,
                                  icon: const Icon(
                                    Icons.cameraswitch_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
