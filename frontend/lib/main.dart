import 'package:flutter/material.dart';

import 'core/navigation/role_router.dart';

void main() {
  runApp(const VanFullApp());
}

class VanFullApp extends StatelessWidget {
  const VanFullApp({this.roles = const [], super.key});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return RoleRouter(roles: roles);
  }
}
