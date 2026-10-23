import 'package:flutter/material.dart';

import '../../core/session/sesion_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// CU-012. Es la misma pantalla para los tres roles: el rol lo define la cuenta.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final SesionController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identificador = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _identificador.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_identificador.text.trim().isEmpty || _password.text.isEmpty) return;
    widget.controller.ingresar(_identificador.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colorError = tema.brightness == Brightness.dark
        ? AppColors.alertDark
        : AppColors.alertLight;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final c = widget.controller;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('VanFull', style: tema.textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Ingresá con tu cuenta',
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        controller: _identificador,
                        enabled: !c.ingresando,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Correo o usuario',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _password,
                        enabled: !c.ingresando,
                        obscureText: _ocultar,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _enviar(),
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          suffixIcon: IconButton(
                            tooltip: _ocultar
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                          ),
                        ),
                      ),
                      if (c.error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          c.error == ErrorLogin.credenciales
                              ? 'El correo o la contraseña no son correctos.'
                              : 'No pudimos conectarnos. Revisá tu conexión e intentá de nuevo.',
                          key: const ValueKey('login-error'),
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: colorError,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: AppSpacing.touchTarget,
                        child: ElevatedButton(
                          onPressed: c.ingresando ? null : _enviar,
                          child: c.ingresando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Ingresar'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
