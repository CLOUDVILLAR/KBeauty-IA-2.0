import 'package:flutter/material.dart';

import '../servicios/servicio_auth.dart';
import '../servicios/servicio_perfil.dart';
import '../tema/tema_app.dart';
import '../utilidades/responsivo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_formulario_piel.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  bool cargandoLogin = false;
  bool cargandoRegistro = false;
  bool cargandoRecuperar = false;
  bool cancelando = false;

  bool get esperandoVillarDo => cargandoLogin || cargandoRegistro;

  @override
  void initState() {
    super.initState();
    ServicioAuth.inicializarEscuchaCallback(
      alIniciarSesion: _continuarLuegoDeVillarDo,
      alError: (mensaje) {
        if (!mounted) return;
        setState(() {
          cargandoLogin = false;
          cargandoRegistro = false;
          cancelando = false;
        });
        mostrarMensaje(context, mensaje);
      },
    );
  }

  @override
  void dispose() {
    ServicioAuth.cerrarEscuchaCallback();
    super.dispose();
  }

  Future<void> _continuarLuegoDeVillarDo() async {
    try {
      final estado = await obtenerEstadoPerfil();
      final completado = estado['formulario_completado'] == true || estado['completado'] == true;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => completado ? const PantallaDashboard() : const PantallaFormularioPiel(),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        cargandoLogin = false;
        cargandoRegistro = false;
      });
      mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _abrirLogin() async {
    setState(() => cargandoLogin = true);
    var mantenerEsperaCallback = false;
    try {
      final sesionCompletada = await ServicioAuth.abrirLoginVillarDo();
      mantenerEsperaCallback = !sesionCompletada;
      if (sesionCompletada) await _continuarLuegoDeVillarDo();
    } catch (error) {
      mantenerEsperaCallback = false;
      final texto = error.toString().replaceFirst('Exception: ', '');
      if (mounted && texto.isNotEmpty && !cancelando) mostrarMensaje(context, texto);
    } finally {
      if (mounted) {
        setState(() {
          cargandoLogin = mantenerEsperaCallback;
          cancelando = false;
        });
      }
    }
  }

  Future<void> _abrirRegistro() async {
    setState(() => cargandoRegistro = true);
    var mantenerEsperaCallback = false;
    try {
      final sesionCompletada = await ServicioAuth.abrirRegistroVillarDo();
      mantenerEsperaCallback = !sesionCompletada;
      if (sesionCompletada) await _continuarLuegoDeVillarDo();
    } catch (error) {
      mantenerEsperaCallback = false;
      final texto = error.toString().replaceFirst('Exception: ', '');
      if (mounted && texto.isNotEmpty && !cancelando) mostrarMensaje(context, texto);
    } finally {
      if (mounted) {
        setState(() {
          cargandoRegistro = mantenerEsperaCallback;
          cancelando = false;
        });
      }
    }
  }

  Future<void> _cancelarInicioWeb() async {
    setState(() {
      cancelando = true;
      cargandoLogin = false;
      cargandoRegistro = false;
    });
    await ServicioAuth.cancelarAutenticacionWeb();
    if (!mounted) return;
    mostrarMensaje(context, 'Inicio de sesión cancelado. Puedes intentarlo de nuevo.');
  }

  Future<void> _abrirRecuperar() async {
    setState(() => cargandoRecuperar = true);
    try {
      await ServicioAuth.abrirRecuperarPassword();
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => cargandoRecuperar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              const SizedBox(height: 18),
              tarjetaGradiente(
                relleno: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.18),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withOpacity(.22)),
                      ),
                      child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'KBeauty IA',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Analiza tu piel, entiende tus avances y sigue una rutina clara.',
                      style: TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroChip(texto: 'SSO Villar.do'),
                        _HeroChip(texto: 'IA real'),
                        _HeroChip(texto: 'Rutinas'),
                      ],
                    ),
                  ],
                ),
              ),
              tarjetaBase(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Acceso seguro',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entra con tu Villar ID. KBeauty no usa formularios propios de login ni registro.',
                      style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    botonPrincipal(
                      texto: 'Continuar con Villar.do',
                      icono: Icons.login_rounded,
                      cargando: cargandoLogin,
                      alPresionar: _abrirLogin,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: (esperandoVillarDo || cargandoRecuperar) ? null : _abrirRegistro,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Crear cuenta en Villar.do'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: (esperandoVillarDo || cargandoRecuperar) ? null : _abrirRecuperar,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Recuperar contraseña'),
                    ),
                    if (esperandoVillarDo) ...[
                      const SizedBox(height: 18),
                      tarjetaSuave(
                        margen: EdgeInsets.zero,
                        hijo: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Esperando respuesta de Villar.do...',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Si cerraste el navegador, cancela este intento y vuelve a iniciar.',
                              style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _cancelarInicioWeb,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancelar inicio'),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}
