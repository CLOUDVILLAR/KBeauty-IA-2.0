import 'package:flutter/material.dart';

import '../servicios/servicio_chat.dart';
import '../tema/tema_app.dart';
import '../utilidades/responsivo.dart';
import '../widgets/mensaje_estado.dart';

class PantallaChatIa extends StatefulWidget {
  const PantallaChatIa({super.key});

  @override
  State<PantallaChatIa> createState() => _PantallaChatIaState();
}

class _PantallaChatIaState extends State<PantallaChatIa> {
  final TextEditingController _controlador = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
  }

  @override
  void dispose() {
    _controlador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mensajes = await obtenerMensajesChat();
      if (!mounted) return;
      setState(() {
        _mensajes
          ..clear()
          ..addAll(mensajes);
      });
      _bajarAlFinal();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _controlador.text.trim();
    if (texto.isEmpty || _enviando) return;

    final temporalUsuario = {
      'rol': 'user',
      'contenido': texto,
      'creado_en': DateTime.now().toIso8601String(),
    };

    setState(() {
      _error = null;
      _enviando = true;
      _mensajes.add(temporalUsuario);
      _controlador.clear();
    });
    _bajarAlFinal();

    try {
      final respuesta = await enviarMensajeChat(texto);
      final usuarioGuardado = respuesta['mensaje_usuario'];
      final ia = respuesta['respuesta_ia'];
      if (!mounted) return;
      setState(() {
        if (usuarioGuardado is Map && _mensajes.isNotEmpty) {
          _mensajes[_mensajes.length - 1] = Map<String, dynamic>.from(usuarioGuardado);
        }
        if (ia is Map) {
          _mensajes.add(Map<String, dynamic>.from(ia));
        }
      });
      _bajarAlFinal();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _bajarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat con KBeauty IA'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _cargando ? null : _cargarMensajes,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: centrarContenido(
          context,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _AvisoContexto(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: mensajeError(_error!),
                ),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _mensajes.isEmpty
                        ? const _EstadoVacio()
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _mensajes.length + (_enviando ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_enviando && index == _mensajes.length) {
                                return const _BurbujaPensando();
                              }
                              return _BurbujaMensaje(mensaje: _mensajes[index]);
                            },
                          ),
              ),
              _EntradaChat(
                controlador: _controlador,
                enviando: _enviando,
                onEnviar: _enviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoContexto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KBeautyColors.rojoSuave,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: KBeautyColors.rojo),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este es tu chat único. La IA usa tu tipo de piel, rutina actual, tu primer análisis y tus 2 análisis más recientes.',
              style: TextStyle(fontWeight: FontWeight.w700, color: KBeautyColors.texto),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Pregúntame sobre tu rutina, tus resultados o qué paso seguir hoy.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({required this.mensaje});

  final Map<String, dynamic> mensaje;

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje['rol'] == 'user';
    final contenido = (mensaje['contenido'] ?? '').toString();
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: esUsuario ? KBeautyColors.rojo : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(esUsuario ? 22 : 6),
            bottomRight: Radius.circular(esUsuario ? 6 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          contenido,
          style: TextStyle(
            color: esUsuario ? Colors.white : KBeautyColors.texto,
            height: 1.35,
            fontWeight: esUsuario ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BurbujaPensando extends StatelessWidget {
  const _BurbujaPensando();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('KBeauty IA está pensando...', style: TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _EntradaChat extends StatelessWidget {
  const _EntradaChat({required this.controlador, required this.enviando, required this.onEnviar});

  final TextEditingController controlador;
  final bool enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controlador,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onEnviar(),
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: enviando ? null : onEnviar,
            icon: enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
