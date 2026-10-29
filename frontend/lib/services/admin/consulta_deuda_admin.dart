import '../../models/pasajero/deuda.dart';

/// Puerto local CU-015, sin ruta HTTP ni política de autorización implícita.
/// null significa que no se obtuvo información: no equivale a saldo cero.
abstract interface class ConsultaDeudaAdmin {
  Future<Deuda?> consultar(int idCliente);
}
