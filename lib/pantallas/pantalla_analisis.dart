import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/servicio_analisis.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_resultado_analisis.dart';

class PantallaAnalisis extends StatefulWidget {
  const PantallaAnalisis({super.key});

  @override
  State<PantallaAnalisis> createState() => _PantallaAnalisisState();
}

class _PantallaAnalisisState extends State<PantallaAnalisis> {
  final selectorImagen = ImagePicker();
  final List<File?> fotos = [null, null, null];

  String metodo = '';
  bool analizando = false;
  bool seleccionando = false;

  List<String> get titulosFotos => [
        'Frente',
        'Lado izquierdo',
        'Lado derecho',
      ];

  List<IconData> get iconosFotos => [
        Icons.face_retouching_natural_outlined,
        Icons.keyboard_arrow_left_rounded,
        Icons.keyboard_arrow_right_rounded,
      ];

  bool get fotosCompletas => fotos.every((foto) => foto != null);

  void seleccionarMetodo(String nuevoMetodo) {
    setState(() {
      metodo = nuevoMetodo;
      fotos[0] = null;
      fotos[1] = null;
      fotos[2] = null;
    });
  }

  void limpiarFotos() {
    setState(() {
      fotos[0] = null;
      fotos[1] = null;
      fotos[2] = null;
    });
  }

  Future<void> tomarFotosEnSecuencia() async {
    if (seleccionando || analizando) return;

    setState(() => seleccionando = true);

    try {
      for (var indice = 0; indice < fotos.length; indice++) {
        if (!mounted) return;

        mostrarMensaje(context, 'Toma la foto: ${titulosFotos[indice]}');

        final imagen = await selectorImagen.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 2200,
        );

        if (imagen == null) {
          mostrarMensaje(context, 'Secuencia cancelada. Puedes volver a intentarlo.');
          return;
        }

        if (!mounted) return;
        setState(() => fotos[indice] = File(imagen.path));
      }

      if (mounted) mostrarMensaje(context, 'Fotos listas para enviar.');
    } catch (error) {
      if (mounted) mostrarMensaje(context, 'No se pudo abrir la camara.');
    } finally {
      if (mounted) setState(() => seleccionando = false);
    }
  }

  XTypeGroup get grupoImagenes => const XTypeGroup(
        label: 'Imagenes',
        mimeTypes: ['image/*'],
        extensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
          'tif',
          'tiff',
          'jfif',
          'heic',
          'heif',
        ],
      );

  Future<void> subirFotosDesdeArchivos() async {
    if (seleccionando || analizando) return;

    setState(() => seleccionando = true);

    try {
      final archivos = await openFiles(acceptedTypeGroups: [grupoImagenes]);

      if (archivos.isEmpty) return;

      final rutas = archivos
          .map((archivo) => archivo.path)
          .where((ruta) => ruta.isNotEmpty)
          .take(3)
          .toList();

      if (rutas.length != 3) {
        if (mounted) {
          mostrarMensaje(
            context,
            'Selecciona exactamente 3 imagenes: frente, lado izquierdo y lado derecho.',
          );
        }
        return;
      }

      setState(() {
        fotos[0] = File(rutas[0]);
        fotos[1] = File(rutas[1]);
        fotos[2] = File(rutas[2]);
      });

      if (mounted) mostrarMensaje(context, 'Imagenes cargadas correctamente.');
    } catch (error) {
      if (mounted) mostrarMensaje(context, 'No se pudieron cargar los archivos.');
    } finally {
      if (mounted) setState(() => seleccionando = false);
    }
  }

  Future<void> cambiarFotoIndividual(int indice) async {
    if (seleccionando || analizando) return;

    if (metodo == 'tomar') {
      final imagen = await selectorImagen.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2200,
      );

      if (imagen != null && mounted) {
        setState(() => fotos[indice] = File(imagen.path));
      }
      return;
    }

    final archivo = await openFile(acceptedTypeGroups: [grupoImagenes]);
    final ruta = archivo?.path;
    if (ruta != null && ruta.isNotEmpty && mounted) {
      setState(() => fotos[indice] = File(ruta));
    }
  }

  Future<void> analizar() async {
    if (!fotosCompletas) {
      mostrarMensaje(
        context,
        'Faltan fotos. Necesitamos frente, lado izquierdo y lado derecho.',
      );
      return;
    }

    setState(() => analizando = true);

    try {
      final resultado = await enviarTresFotosAnalisis(
        frente: fotos[0]!,
        ladoIzquierdo: fotos[1]!,
        ladoDerecho: fotos[2]!,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaResultadoAnalisis(resultado: resultado),
        ),
      );
    } catch (error) {
      if (mounted) {
        mostrarMensaje(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => analizando = false);
    }
  }

  Widget construirSelectorMetodo() {
    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analisis con 3 fotos',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Primero elige como quieres agregar las imagenes. Necesitamos una foto de frente y dos laterales para que la IA tenga una vista mas completa.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _tarjetaMetodo(
                  titulo: 'Tomarlas ahora',
                  descripcion: 'La camara se abrira en secuencia.',
                  icono: Icons.camera_alt_outlined,
                  alPresionar: () => seleccionarMetodo('tomar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaMetodo(
                  titulo: 'Subir fotos',
                  descripcion: 'Usa galeria o archivos de la computadora.',
                  icono: Icons.upload_file_outlined,
                  alPresionar: () => seleccionarMetodo('subir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaMetodo({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required VoidCallback alPresionar,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: alPresionar,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 32),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              descripcion,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirVistaFotos() {
    final esCamara = metodo == 'tomar';

    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  esCamara ? 'Tomar fotos' : 'Subir fotos',
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: analizando || seleccionando ? null : () => seleccionarMetodo(''),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            esCamara
                ? 'Presiona el boton y toma las fotos en este orden: frente, lado izquierdo y lado derecho.'
                : 'Presiona el boton y selecciona 3 imagenes en este orden: frente, lado izquierdo y lado derecho. Tambien funciona desde la computadora.',
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(
              3,
              (indice) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: indice == 2 ? 0 : 8),
                  child: construirCuadroFoto(indice),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          botonPrincipal(
            texto: esCamara ? 'Tomar foto' : 'Subir fotos',
            icono: esCamara ? Icons.camera_alt_outlined : Icons.folder_open_outlined,
            cargando: seleccionando,
            alPresionar: esCamara ? tomarFotosEnSecuencia : subirFotosDesdeArchivos,
          ),
          const SizedBox(height: 10),
          if (fotosCompletas)
            botonPrincipal(
              texto: 'Enviar fotos',
              icono: Icons.auto_awesome,
              cargando: analizando,
              alPresionar: analizar,
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Enviar fotos'),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: analizando || seleccionando ? null : limpiarFotos,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Limpiar fotos'),
          ),
        ],
      ),
    );
  }

  Widget construirCuadroFoto(int indice) {
    final foto = fotos[indice];

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => cambiarFotoIndividual(indice),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 0.82,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: foto == null ? Colors.black12 : Theme.of(context).colorScheme.primary,
                  width: foto == null ? 1 : 2,
                ),
              ),
              child: foto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconosFotos[indice], size: 34, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text(
                          '${indice + 1}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(foto, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titulosFotos[indice],
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analizar piel')),
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              if (metodo.isEmpty) construirSelectorMetodo() else construirVistaFotos(),
              const SizedBox(height: 14),
              tarjetaBase(
                hijo: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Las imagenes solo se usan para el analisis. No se guardan en la app, en la API ni en la base de datos.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
