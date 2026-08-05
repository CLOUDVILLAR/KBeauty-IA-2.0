import 'package:flutter/material.dart';

import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/campo_texto.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_captura_promotoras.dart';

/// Pide nombre y telefono del cliente walk-in ANTES de tomar las fotos, para
/// validar el telefono temprano y no perder tiempo si es invalido.
class PantallaDatosCliente extends StatefulWidget {
  const PantallaDatosCliente({super.key});

  @override
  State<PantallaDatosCliente> createState() => _PantallaDatosClienteState();
}

class _PantallaDatosClienteState extends State<PantallaDatosCliente> {
  final _nombreControlador = TextEditingController();
  final _apellidoControlador = TextEditingController();
  final _telefonoControlador = TextEditingController();

  @override
  void dispose() {
    _nombreControlador.dispose();
    _apellidoControlador.dispose();
    _telefonoControlador.dispose();
    super.dispose();
  }

  void continuar() {
    final nombre = _nombreControlador.text.trim();
    final telefono = _telefonoControlador.text.trim();
    final soloDigitos = telefono.replaceAll(RegExp('[^0-9]'), '');

    if (nombre.isEmpty) {
      mostrarMensaje(context, 'Escribe el nombre del cliente.');
      return;
    }
    if (soloDigitos.length < 10) {
      mostrarMensaje(context, 'Escribe un telefono valido (10 digitos).');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCapturaPromotoras(
          clienteNombre: nombre,
          clienteApellido: _apellidoControlador.text.trim(),
          clienteTelefono: telefono,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del cliente')),
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
                    const Text(
                      'Antes de las fotos',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pide el nombre y telefono del cliente para poder guardar su analisis.',
                    ),
                    const SizedBox(height: 18),
                    campoTexto(
                      controlador: _nombreControlador,
                      etiqueta: 'Nombre',
                      icono: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    campoTexto(
                      controlador: _apellidoControlador,
                      etiqueta: 'Apellido (opcional)',
                      icono: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    campoTexto(
                      controlador: _telefonoControlador,
                      etiqueta: 'Telefono',
                      icono: Icons.phone_outlined,
                      tipo: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    botonPrincipal(
                      texto: 'Continuar a las fotos',
                      icono: Icons.arrow_forward_rounded,
                      alPresionar: continuar,
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
