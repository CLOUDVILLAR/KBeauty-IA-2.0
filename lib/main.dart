import 'package:flutter/material.dart';

import 'pantallas/pantalla_inicio.dart';
import 'tema/tema_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KBeautyApp());
}

class KBeautyApp extends StatelessWidget {
  const KBeautyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBeauty IA',
      debugShowCheckedModeBanner: false,
      theme: crearTemaApp(),
      home: const PantallaInicio(),
    );
  }
}
