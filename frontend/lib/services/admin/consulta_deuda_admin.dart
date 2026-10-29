import '../../models/pasajero/deuda.dart';

/// Puerto CU-015: el adaptador HTTP usa la consulta administrativa autorizada.
/// null significa que no se obtuvo información: no equivale a saldo cero.
abstract interface class ConsultaDeudaAdmin {
  Future<Deuda?> consultar(int idCliente);
}
