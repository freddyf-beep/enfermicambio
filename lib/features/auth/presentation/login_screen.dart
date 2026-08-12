import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: '123456');
  bool _isBusy = false;
  AsyncViewStatus? _status;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isBusy = true;
      _status = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isBusy = false;
          _status = const AsyncViewStatus.retryableFailure(
            'El inicio de sesión con Google fue cancelado.',
          );
        });
        return;
      }
      final googleAuth = await googleUser.authentication;
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      setState(() {
        _isBusy = false;
      });
    } on Exception catch (error) {
      setState(() {
        _isBusy = false;
        _status = AsyncViewStatus.backendError(error.toString());
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isBusy = true;
      _status = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      setState(() {
        _isBusy = false;
      });
    } on AuthException catch (error) {
      setState(() {
        _isBusy = false;
        _status = AsyncViewStatus.backendError(error.message);
      });
    } on Exception catch (error) {
      setState(() {
        _isBusy = false;
        _status = AsyncViewStatus.backendError(error.toString());
      });
    }
  }

  void _quickFillUser(String email, String name) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = '123456';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Cargado usuario $name ($email)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    size: 64,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enfermicambio',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Competencia fitness privada entre 4 amigos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continuar con Google'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Acceso rápido: 2 de 4 cuentas activadas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick login buttons for the 4 users
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text('Freddy'),
                      onPressed: () =>
                          _quickFillUser('udefret12@gmail.com', 'Freddy'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text('Felipe'),
                      onPressed: () =>
                          _quickFillUser('felipe.seron03@gmail.com', 'Felipe'),
                    ),
                    const Tooltip(
                      message:
                          'La cuenta de Cristian aún no está creada en Supabase.',
                      child: ActionChip(
                        avatar: Icon(Icons.person, size: 16),
                        label: Text('Cristian'),
                        onPressed: null,
                      ),
                    ),
                    const Tooltip(
                      message:
                          'La cuenta de Samir aún no está creada en Supabase.',
                      child: ActionChip(
                        avatar: Icon(Icons.person, size: 16),
                        label: Text('Samir'),
                        onPressed: null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (por defecto 123456)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isBusy ? null : _signInWithEmail,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Iniciar Sesión'),
                ),
                if (_isBusy) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 24),
                  AsyncStateView(status: _status!, child: const SizedBox()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
