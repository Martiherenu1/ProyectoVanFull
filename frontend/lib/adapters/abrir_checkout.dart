import 'package:url_launcher/url_launcher.dart';

import '../services/checkout_api.dart';

/// Un gesto explícito evita el popup bloqueado tras esperar el POST en Web.
/// En Mobile abre navegador externo; nunca interpreta el retorno como acreditación.
Future<bool> abrirCheckoutExterno(
  Uri url, {
  Future<bool> Function(Uri, LaunchMode, String)? lanzar,
}) {
  final seguro = validarUrlCheckout(url.toString());
  if (lanzar != null) {
    return lanzar(seguro, LaunchMode.externalApplication, '_blank');
  }
  return launchUrl(
    seguro,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
