import 'package:flutter/material.dart';

import '../tema/tema_app.dart';
import '../utilidades/responsivo.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_analisis.dart';
import 'pantalla_analisis_externo.dart';
import 'pantalla_evolucion.dart';
import 'pantalla_historial.dart';
import 'pantalla_cerrando_sesion.dart';
import 'pantalla_chat_ia.dart';
import 'pantalla_perfil.dart';
import 'pantalla_rutina.dart';

class PantallaDashboard extends StatelessWidget {
  const PantallaDashboard({super.key});

  void salir(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaCerrandoSesion()),
      (_) => false,
    );
  }

  void abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final opciones = [
      _OpcionDashboard(
        titulo: 'Analizar piel',
        subtitulo: 'Nueva foto y recomendación IA',
        icono: Icons.camera_alt_rounded,
        color: KBeautyColors.rojo,
        pantalla: const PantallaAnalisis(),
      ),

      _OpcionDashboard(
        titulo: 'Importar analisis externo',
        subtitulo: 'PDF facial y rutina IA',
        icono: Icons.picture_as_pdf_rounded,
        color: const Color(0xFF14B8A6),
        pantalla: const PantallaAnalisisExterno(),
      ),
      _OpcionDashboard(
        titulo: 'Evolución',
        subtitulo: 'Tus avances en el tiempo',
        icono: Icons.trending_up_rounded,
        color: const Color(0xFF7C3AED),
        pantalla: const PantallaEvolucion(),
      ),
      _OpcionDashboard(
        titulo: 'Historial',
        subtitulo: 'Análisis anteriores',
        icono: Icons.history_rounded,
        color: const Color(0xFF0EA5E9),
        pantalla: const PantallaHistorial(),
      ),
      _OpcionDashboard(
        titulo: 'Rutina',
        subtitulo: 'Plan recomendado',
        icono: Icons.spa_rounded,
        color: const Color(0xFF10B981),
        pantalla: const PantallaRutina(),
      ),
      _OpcionDashboard(
        titulo: 'Chat IA',
        subtitulo: 'Pregunta con tu contexto de piel',
        icono: Icons.chat_bubble_rounded,
        color: const Color(0xFFEC4899),
        pantalla: const PantallaChatIa(),
      ),
      _OpcionDashboard(
        titulo: 'Perfil',
        subtitulo: 'Cuenta y tipo de piel',
        icono: Icons.person_rounded,
        color: const Color(0xFFF59E0B),
        pantalla: const PantallaPerfil(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: centrarContenido(
          context,
          ListView(
            padding: margenPantalla(context),
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KBeautyColors.rojoSuave,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: KBeautyColors.rojo),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KBeauty IA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        Text('Tu piel, leída con inteligencia', style: TextStyle(color: KBeautyColors.textoSuave)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Salir',
                    onPressed: () => salir(context),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              tarjetaGradiente(
                hijo: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, piel luminosa',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Haz un análisis, revisa tu rutina y compara tus avances sin saturarte de números.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PildoraHero(texto: 'IA real'),
                        _PildoraHero(texto: 'Rutina clara'),
                        _PildoraHero(texto: 'Progreso'),
                      ],
                    ),
                  ],
                ),
              ),
              tituloSeccion('Acciones principales', subtitulo: 'Elige qué quieres hacer ahora'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dosColumnas = constraints.maxWidth > 430;
                  if (!dosColumnas) {
                    return Column(
                      children: opciones.map((opcion) => _TarjetaOpcion(opcion: opcion, onTap: () => abrir(context, opcion.pantalla))).toList(),
                    );
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.08,
                    children: opciones.map((opcion) => _TarjetaOpcion(opcion: opcion, onTap: () => abrir(context, opcion.pantalla), compacto: true)).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionDashboard {
  const _OpcionDashboard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.pantalla,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final Widget pantalla;
}

class _PildoraHero extends StatelessWidget {
  const _PildoraHero({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20)),
      ),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  const _TarjetaOpcion({required this.opcion, required this.onTap, this.compacto = false});

  final _OpcionDashboard opcion;
  final VoidCallback onTap;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: tarjetaBase(
        margen: compacto ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
        relleno: const EdgeInsets.all(18),
        hijo: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: opcion.color.withOpacity(.11),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(opcion.icono, color: opcion.color),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: opcion.color),
              ],
            ),
            const SizedBox(height: 18),
            Text(opcion.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(opcion.subtitulo, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
