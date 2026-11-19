enum AppRole {
  passenger('pasajero'),
  driver('chofer'),
  admin('administrador'),
  owner('dueno');

  const AppRole(this.apiValue);

  final String apiValue;

  static AppRole? fromApiValue(String value) {
    for (final role in values) {
      if (role.apiValue == value) {
        return role;
      }
    }
    return null;
  }
}
