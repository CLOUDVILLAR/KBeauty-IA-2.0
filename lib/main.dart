import 'package:flutter/material.dart';

import 'pantallas/pantalla_inicio_promotoras.dart';
import 'tema/tema_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KBeautyApp());
}

/// Rama `promotoras`: sin login, sin formulario de perfil. Entra directo al
/// flujo de analisis para clientes walk-in en tablets de evento.
class KBeautyApp extends StatelessWidget {
  const KBeautyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBeauty Promotoras',
      debugShowCheckedModeBanner: false,
      theme: crearTemaApp(),
      home: const PantallaInicioPromotoras(),
    );
  }
}
