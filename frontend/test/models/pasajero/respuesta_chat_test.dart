import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pasajero/respuesta_chat.dart';

void main() {
  group('RespuestaChat', () {
    test('lee todos los campos del contrato', () {
      final r = RespuestaChat.fromJson({
        'respuesta': 'Hay 14 lugares.',
        'conversacion_id': 'c-1',
        'derivar_humano': true,
        'tool_usada': 'consultar_disponibilidad',
      });

      expect(r.respuesta, 'Hay 14 lugares.');
      expect(r.conversacionId, 'c-1');
      expect(r.derivarHumano, isTrue);
      expect(r.toolUsada, 'consultar_disponibilidad');
    });

    test(
      'tool_usada nula y derivar_humano ausente quedan en sus valores base',
      () {
        final r = RespuestaChat.fromJson({
          'respuesta': 'Hola',
          'conversacion_id': 'c-1',
          'tool_usada': null,
        });

        expect(r.derivarHumano, isFalse);
        expect(r.toolUsada, isNull);
      },
    );

    test('sin conversacion_id no es una respuesta válida', () {
      expect(
        () => RespuestaChat.fromJson({'respuesta': 'Hola'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
