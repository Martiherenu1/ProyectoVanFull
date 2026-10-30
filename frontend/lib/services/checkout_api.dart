import 'dart:math';

import '../core/api/api_client.dart';
import '../models/pasajero/pago.dart';

typedef IniciarCheckout = Future<InicioCheckout> Function(
  double importe,
  String clave,
);
typedef ConsultarPagoPropio = Future<Pago> Function(int idPago);
typedef AbrirCheckout = Future<bool> Function(Uri url);

String nuevaClaveCheckout() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

Uri validarUrlCheckout(String valor) {
  final url = Uri.parse(valor);
  if (url.scheme != 'https' ||
      !const {
        'sandbox.mercadopago.com',
        'sandbox.mercadopago.com.ar',
      }.contains(url.host) ||
      url.userInfo.isNotEmpty ||
      url.port != 443 ||
      url.hasFragment ||
      (url.queryParametersAll['pref_id']?.length ?? 0) != 1 ||
      !RegExp(r'^[A-Za-z0-9_-]{1,160}$')
          .hasMatch(url.queryParameters['pref_id'] ?? '')) {
    throw const FormatException(
      'Enlace Checkout fuera del entorno de pruebas.',
    );
  }
  return url;
}

class InicioCheckout {
  const InicioCheckout({required this.pago, required this.estado, this.url});
  factory InicioCheckout.fromJson(Map<String, dynamic> json) {
    final estado = json['estado_checkout'] as String;
    if (!const {'CREANDO', 'LISTO', 'INCIERTO'}.contains(estado)) {
      throw const FormatException('Estado de inicio desconocido.');
    }
    final enlace = json['checkout_url'] as String?;
    return InicioCheckout(
      pago: Pago.fromJson(json['pago'] as Map<String, dynamic>),
      estado: estado,
      url: enlace == null ? null : validarUrlCheckout(enlace),
    );
  }
  final Pago pago;
  final String estado;
  final Uri? url;
}

class CheckoutApi {
  const CheckoutApi(
    this._cliente, {
    this.timeout = const Duration(seconds: 25),
  });
  final ApiClient _cliente;
  final Duration timeout;

  Future<InicioCheckout> iniciar(double importe, String clave) async {
    final json = await _cliente
        .post(
          'pagos/mercadopago/checkout',
          body: {
            'importe': importe,
            'medio_pago': 'MERCADO_PAGO',
            'clave_solicitud': clave,
          },
        )
        .timeout(timeout);
    return InicioCheckout.fromJson(json! as Map<String, dynamic>);
  }

  Future<Pago> consultar(int idPago) async => Pago.fromJson(
    (await _cliente.get('pagos/$idPago').timeout(timeout))!
        as Map<String, dynamic>,
  );
}
