import 'package:flutter/material.dart';

import '../servicios/servicio_auth.dart';
import '../servicios/servicio_perfil.dart';
import '../tema/tema_app.dart';
import '../utilidades/formato.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';
import '../widgets/tarjeta_base.dart';
import 'pantalla_formulario_piel.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  late Future<Map<String, dynamic>> futuro;

  @override
  void initState() {
    super.initState();
    futuro = cargarPerfilCompleto();
  }

  Future<Map<String, dynamic>> cargarPerfilCompleto() async {
    final usuario = await obtenerUsuarioActual();
    final piel = await obtenerFormularioPiel();
    return {'usuario': usuario, 'piel': piel};
  }

  void _recargar() {
    setState(() => futuro = cargarPerfilCompleto());
  }

  Map<String, dynamic> obtenerDatosVillar(Map<String, dynamic> usuario) {
    return mapaSeguro(usuario['datos_villar'] ?? usuario['usuario_villar']);
  }

  String _dato(Object? valor, [String defecto = 'No indicado']) {
    return textoSeguro(valor, defecto);
  }

  String _nombreCompleto(Map<String, dynamic> datosVillar) {
    final nombre = textoSeguro(datosVillar['nombre'], '');
    final apellido = textoSeguro(datosVillar['apellido'], '');
    final completo = '$nombre $apellido'.trim();
    if (completo.isNotEmpty) return completo;
    return textoSeguro(datosVillar['correo'], 'Mi perfil');
  }

  String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.trim().isNotEmpty)
        .toList();
    if (partes.isEmpty) return 'K';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return '${partes.first.characters.first}${partes.last.characters.first}'.toUpperCase();
  }

  bool _tienePerfilPiel(Map<String, dynamic> piel) {
    return piel.values.any((valor) => textoSeguro(valor).isNotEmpty);
  }

  String _resumenPiel(Map<String, dynamic> piel) {
    final tipo = textoSeguro(piel['tipo_piel'], 'tu tipo de piel');
    final condicion = textoSeguro(piel['condicion_principal'], 'tu objetivo principal');
    if (!_tienePerfilPiel(piel)) {
      return 'Completa tu perfil de piel para que la IA pueda recomendar rutinas mas precisas.';
    }
    return 'Tu perfil indica $tipo, con foco en $condicion. Esta informacion ayuda a personalizar cada analisis.';
  }

  Future<void> _abrirFormularioPiel() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaFormularioPiel()),
    );
    if (mounted) _recargar();
  }

  Widget _heroPerfil(Map<String, dynamic> usuario, Map<String, dynamic> datosVillar) {
    final nombre = _nombreCompleto(datosVillar);
    final correo = _dato(datosVillar['correo'], 'Correo no indicado');
    final estado = _dato(datosVillar['estado'] ?? usuario['estado_en_app'], 'Activo');

    return tarjetaGradiente(
      relleno: const EdgeInsets.all(22),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(.35)),
                ),
                child: Center(
                  child: Text(
                    _iniciales(nombre),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi cuenta',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chipHero(Icons.verified_user_outlined, estado),
              _chipHero(Icons.shield_outlined, 'Villar ID conectado'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipHero(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _tarjetaPiel(Map<String, dynamic> piel) {
    final tienePerfil = _tienePerfilPiel(piel);

    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconoSeccion(Icons.face_retouching_natural_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Perfil de piel',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: KBeautyColors.texto),
                ),
              ),
              TextButton.icon(
                onPressed: _abrirFormularioPiel,
                icon: Icon(tienePerfil ? Icons.edit_outlined : Icons.add_rounded, size: 18),
                label: Text(tienePerfil ? 'Editar' : 'Completar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _resumenPiel(piel),
            style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chipInfo('Tipo', _dato(piel['tipo_piel'])),
              _chipInfo('Objetivo', _dato(piel['condicion_principal'])),
              _chipInfo('Edad', _dato(piel['rango_edad'])),
              _chipInfo('Sensibilidad', _dato(piel['sensibilidad'])),
              _chipInfo('Protector solar', _dato(piel['usa_protector_solar'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCuenta(Map<String, dynamic> usuario, Map<String, dynamic> datosVillar) {
    return tarjetaBase(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconoSeccion(Icons.badge_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Datos de Villar.do',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: KBeautyColors.texto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _datoGrande(
            icono: Icons.fingerprint_rounded,
            titulo: 'Villar ID',
            valor: _dato(usuario['villar_id'] ?? datosVillar['villar_id']),
          ),
          _datoGrande(
            icono: Icons.phone_outlined,
            titulo: 'Telefono',
            valor: _dato(datosVillar['telefono']),
          ),
          _datoGrande(
            icono: Icons.location_on_outlined,
            titulo: 'Ubicacion',
            valor: _ubicacion(datosVillar),
          ),
        ],
      ),
    );
  }

  String _ubicacion(Map<String, dynamic> datosVillar) {
    final ciudad = textoSeguro(datosVillar['ciudad'], '');
    final pais = textoSeguro(datosVillar['pais'], '');
    final texto = [ciudad, pais].where((item) => item.isNotEmpty).join(', ');
    return texto.isEmpty ? 'No indicada' : texto;
  }

  Widget _iconoSeccion(IconData icono) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: KBeautyColors.rojoSuave,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icono, color: KBeautyColors.rojo, size: 23),
    );
  }

  Widget _chipInfo(String titulo, String valor) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KBeautyColors.rosaMuySuave,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KBeautyColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            valor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _datoGrande({required IconData icono, required String titulo, required String valor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KBeautyColors.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KBeautyColors.rojoSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icono, color: KBeautyColors.rojo, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  valor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaConsejo() {
    return tarjetaSuave(
      hijo: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.tips_and_updates_outlined, color: KBeautyColors.rojo),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mantener tu perfil de piel actualizado ayuda a que cada analisis y rutina sea mas precisa.',
              style: TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return cargandoCentro('Cargando perfil...');
          }
          if (snapshot.hasError) {
            return mensajeError(
              snapshot.error.toString(),
              alReintentar: _recargar,
            );
          }

          final usuario = mapaSeguro(snapshot.data?['usuario']);
          final datosVillar = obtenerDatosVillar(usuario);
          final piel = mapaSeguro(snapshot.data?['piel']);

          return SafeArea(
            child: RefreshIndicator(
              color: KBeautyColors.rojo,
              onRefresh: () async {
                _recargar();
                await futuro;
              },
              child: centrarContenido(
                context,
                ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: margenPantalla(context),
                  children: [
                    _heroPerfil(usuario, datosVillar),
                    _tarjetaPiel(piel),
                    _tarjetaCuenta(usuario, datosVillar),
                    _tarjetaConsejo(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
