import 'dart:io';

import 'package:flutter/material.dart';

import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/guia_posicion_cara.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_analizando_promotoras.dart';
import 'pantalla_camara_guiada.dart';

/// Captura de las 3 fotos para el flujo de promotoras. A diferencia de
/// PantallaAnalisis, no ofrece "subir archivos": en una tablet de evento solo
/// tiene sentido tomar las fotos con la camara.
class PantallaCapturaPromotoras extends StatefulWidget {
  const PantallaCapturaPromotoras({
    super.key,
    required this.clienteNombre,
    required this.clienteApellido,
    required this.clienteTelefono,
  });

  final String clienteNombre;
  final String clienteApellido;
  final String clienteTelefono;

  @override
  State<PantallaCapturaPromotoras> createState() => _PantallaCapturaPromotorasState();
}

class _PantallaCapturaPromotorasState extends State<PantallaCapturaPromotoras> {
  final List<File?> fotos = [null, null, null];
  bool tomando = false;

  static const _titulos = ['Frente', 'Lado izquierdo', 'Lado derecho'];
  static const _iconos = [
    Icons.face_retouching_natural_outlined,
    Icons.keyboard_arrow_left_rounded,
    Icons.keyboard_arrow_right_rounded,
  ];

  bool get fotosCompletas => fotos.every((foto) => foto != null);

  Future<void> tomarFotosEnSecuencia() async {
    if (tomando) return;
    setState(() => tomando = true);

    try {
      for (var indice = 0; indice < fotos.length; indice++) {
        if (!mounted) return;

        final continuar = await mostrarGuiaPosicionCara(context, indice);
        if (!continuar) {
          if (mounted) mostrarMensaje(context, 'Secuencia cancelada. Puedes volver a intentarlo.');
          return;
        }
        if (!mounted) return;

        final File? imagen = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaCamaraGuiada(indice: indice)),
        );

        if (imagen == null) {
          if (mounted) mostrarMensaje(context, 'Secuencia cancelada. Puedes volver a intentarlo.');
          return;
        }

        if (!mounted) return;
        setState(() => fotos[indice] = imagen);
      }
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo abrir la camara.');
    } finally {
      if (mounted) setState(() => tomando = false);
    }
  }

  void limpiarFotos() {
    setState(() {
      fotos[0] = null;
      fotos[1] = null;
      fotos[2] = null;
    });
  }

  void analizar() {
    if (!fotosCompletas) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaAnalizandoPromotoras(
          frente: fotos[0]!,
          ladoIzquierdo: fotos[1]!,
          ladoDerecho: fotos[2]!,
          clienteNombre: widget.clienteNombre,
          clienteApellido: widget.clienteApellido,
          clienteTelefono: widget.clienteTelefono,
        ),
      ),
    );
  }

  Widget construirCuadroFoto(int indice) {
    final foto = fotos[indice];
    return Column(
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
                      Icon(_iconos[indice], size: 34, color: Colors.grey.shade600),
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
          _titulos[indice],
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fotos de ${widget.clienteNombre}')),
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              tarjetaBase(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tomar fotos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Toma las 3 fotos en este orden: frente, lado izquierdo y lado derecho.'),
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
                      texto: 'Tomar foto',
                      icono: Icons.camera_alt_outlined,
                      cargando: tomando,
                      alPresionar: tomarFotosEnSecuencia,
                    ),
                    const SizedBox(height: 10),
                    if (fotosCompletas)
                      botonPrincipal(
                        texto: 'Analizar',
                        icono: Icons.auto_awesome,
                        alPresionar: analizar,
                      )
                    else
                      const OutlinedButton(
                        onPressed: null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline),
                            SizedBox(width: 8),
                            Text('Analizar'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: tomando ? null : limpiarFotos,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Limpiar fotos'),
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
