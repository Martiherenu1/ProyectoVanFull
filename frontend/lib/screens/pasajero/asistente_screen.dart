import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/respuesta_chat.dart';

/// El adaptador común deberá hacer POST /chat con `mensaje` y, desde el segundo
/// mensaje, el `conversacion_id` que devolvió la respuesta anterior.
typedef EnviarMensaje = Future<RespuestaChat> Function(
  String mensaje,
  String? conversacionId,
);

/// Largo máximo de un mensaje que acepta el backend.
const int maxCaracteresMensaje = 2000;

/// CU-011. La pantalla no crea clientes HTTP ni decide qué responde ni qué
/// herramientas usa el asistente: muestra lo que devuelve el backend.
class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key, required this.enviarMensaje});

  final EnviarMensaje enviarMensaje;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _Mensaje {
  _Mensaje.delPasajero(this.texto) : esDelPasajero = true, derivado = false;

  _Mensaje.delAsistente(this.texto, {required this.derivado})
    : esDelPasajero = false;

  final String texto;
  final bool esDelPasajero;

  /// Solo en mensajes del asistente: derivó a una persona (RF-032).
  final bool derivado;

  /// Solo en mensajes del pasajero: no llegó al backend.
  bool fallido = false;
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _controlador = TextEditingController();
  final List<_Mensaje> _mensajes = [];
  String? _conversacionId;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _controlador.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  bool get _puedeEnviar => !_enviando && _controlador.text.trim().isNotEmpty;

  void _enviarEscrito() {
    final texto = _controlador.text.trim();
    if (_enviando || texto.isEmpty) return;
    final mensaje = _Mensaje.delPasajero(texto);
    setState(() => _mensajes.add(mensaje));
    _controlador.clear();
    _enviar(mensaje);
  }

  void _reintentar(_Mensaje mensaje) {
    if (_enviando) return;
    _enviar(mensaje);
  }

  Future<void> _enviar(_Mensaje mensaje) async {
    setState(() {
      _enviando = true;
      mensaje.fallido = false;
    });
    try {
      final respuesta = await widget.enviarMensaje(
        mensaje.texto,
        _conversacionId,
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _conversacionId = respuesta.conversacionId;
        _mensajes.add(
          _Mensaje.delAsistente(
            respuesta.respuesta,
            derivado: respuesta.derivarHumano,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        mensaje.fallido = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Asistente')),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _conversacion(context)),
                _entrada(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conversacion(BuildContext context) {
    if (_mensajes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Preguntame por viajes, cupos o tus reservas. Si preferís hablar '
          'con una persona, pedímelo. Los pagos no los confirmo yo.',
          key: const ValueKey('presentacion'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    // Lista invertida: el mensaje más nuevo queda abajo, sin manejar el scroll.
    final filas = <Widget>[
      if (_enviando) const _Escribiendo(),
      for (final mensaje in _mensajes.reversed)
        _Burbuja(mensaje: mensaje, onReintentar: () => _reintentar(mensaje)),
    ];
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: filas.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) => filas[index],
    );
  }

  Widget _entrada(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('mensaje'),
              controller: _controlador,
              minLines: 1,
              maxLines: 4,
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxCaracteresMensaje),
              ],
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Escribí tu consulta',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            child: IconButton.filled(
              key: const ValueKey('enviar'),
              tooltip: 'Enviar',
              onPressed: _puedeEnviar ? _enviarEscrito : null,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje, required this.onReintentar});

  final _Mensaje mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final delPasajero = mensaje.esDelPasajero;
    return Align(
      alignment: delPasajero ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: delPasajero
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              label: delPasajero ? 'Vos' : 'Asistente',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: delPasajero ? null : tema.colorScheme.surface,
                  border: Border.all(
                    color: tema.colorScheme.outline,
                    width: AppSpacing.borderWidth,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(mensaje.texto, style: tema.textTheme.bodyMedium),
                ),
              ),
            ),
            if (mensaje.derivado)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'DERIVADO A UNA PERSONA DE VANFULL',
                  key: const ValueKey('derivado'),
                  style: tema.textTheme.labelSmall,
                ),
              ),
            if (mensaje.fallido)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo enviar.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: AppColors.alertDark,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('reintentar-mensaje'),
                    onPressed: onReintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Mientras el asistente responde: texto, no un spinner (brief §8).
class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'El asistente está respondiendo…',
        key: const ValueKey('escribiendo'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
