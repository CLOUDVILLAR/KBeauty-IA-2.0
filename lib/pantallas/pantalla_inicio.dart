import 'package:flutter/material.dart';

import '../servicios/servicio_api.dart';
import '../servicios/servicio_perfil.dart';
import '../tema/tema_app.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_formulario_piel.dart';
import 'pantalla_login.dart';
import 'pantalla_cerrando_sesion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  @override
  void initState() {
    super.initState();
    revisarSesion();
  }

  Future<void> revisarSesion() async {
    final cerrando = await hayCierreSesionEnCurso();
    if (!mounted) return;
    if (cerrando) {
      abrir(const PantallaCerrandoSesion());
      return;
    }

    final token = await obtenerToken();
    final villarId = await obtenerVillarId();
    if (!mounted) return;
    if (token == null || token.isEmpty || villarId == null || villarId.isEmpty) {
      abrir(const PantallaLogin());
      return;
    }
    try {
      final estado = await obtenerEstadoPerfil();
      final completado = estado['formulario_completado'] == true || estado['completado'] == true;
      abrir(completado ? const PantallaDashboard() : const PantallaFormularioPiel());
    } catch (_) {
      await borrarToken();
      if (mounted) abrir(const PantallaLogin());
    }
  }

  void abrir(Widget pantalla) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SplashLogo(),
            SizedBox(height: 18),
            Text('KBeauty IA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('Preparando tu experiencia', style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700)),
            SizedBox(height: 22),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [KBeautyColors.rojo, Color(0xFFFF5B60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: KBeautyColors.rojo.withOpacity(.28), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 42),
    );
  }
}
