import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/firebase_auth_service.dart';
import '../data/firebase_profile_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'CambiarEsto123!');
  late final FirebaseAuthService _firebaseAuth;
  late final FirebaseProfileRepository _firebaseProfiles;
  bool _isBusy = false;
  AsyncViewStatus? _status;

  bool get _firebaseMode =>
      AppEnvironment.firebaseAuthEnabled && Firebase.apps.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firebaseAuth = FirebaseAuthService();
    _firebaseProfiles = FirebaseProfileRepository();
  }

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
      if (_firebaseMode) {
        final firebaseCredential = await _firebaseAuth.signInWithGoogle();
        if (firebaseCredential == null) {
          if (!mounted) return;
          setState(() {
            _isBusy = false;
            _status = const AsyncViewStatus.retryableFailure(
              'El inicio de sesión con Google fue cancelado.',
            );
          });
          return;
        }
        await _saveFirebaseProfile(firebaseCredential.user);
        await _bridgeGoogleSessionToSupabase(firebaseCredential);
        if (!mounted) return;
        setState(() {
          _isBusy = false;
        });
        return;
      }
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
      if (_firebaseMode) {
        final firebaseCredential = await _firebaseAuth.signInWithEmail(
          email: email,
          password: password,
        );
        await _saveFirebaseProfile(firebaseCredential.user);
        // Existing feature repositories still use Supabase. Keeping both
        // sessions alive lets the migration happen without breaking the app.
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        setState(() {
          _isBusy = false;
        });
        return;
      }
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

  Future<void> _saveFirebaseProfile(firebase_auth.User? user) async {
    if (user == null) return;
    try {
      await _firebaseProfiles.upsertFromAuthUser(user);
    } on Exception {
      // Firestore rules/database provisioning can be completed independently
      // of Auth. A temporary profile write failure must not discard a valid
      // Firebase session.
    }
  }

  Future<void> _bridgeGoogleSessionToSupabase(
    firebase_auth.UserCredential credential,
  ) async {
    final oauth = credential.credential;
    if (oauth is! firebase_auth.OAuthCredential || oauth.idToken == null) {
      throw const AuthException(
        'Google entregó una sesión de Firebase, pero falta el token compatible con la sesión de datos actual.',
      );
    }
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: oauth.idToken!,
      accessToken: oauth.accessToken,
    );
  }

  Future<void> _signInWithPhone() async {
    if (!_firebaseMode) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _FirebasePhoneDialog(service: _firebaseAuth),
    );
    if (!mounted || result != true) return;
    setState(() {
      _status = const AsyncViewStatus.retryableFailure(
        'Teléfono verificado en Firebase. La sesión de datos de la app todavía requiere completar la migración desde Supabase.',
      );
    });
  }

  void _quickFillUser(String email, String name) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = 'CambiarEsto123!';
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
                const Center(child: AppLogo(size: 104, borderRadius: 28)),
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
                        'Acceso rápido: 4 de 4 cuentas activadas',
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
                      label: const Text('Pipe'),
                      onPressed: () =>
                          _quickFillUser('felipe.seron03@gmail.com', 'Pipe'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text('Sami'),
                      onPressed: () =>
                          _quickFillUser('samineiror123@gmail.com', 'Sami'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text('Cruz'),
                      onPressed: () => _quickFillUser(
                        'cristiancarrillo262@gmail.com',
                        'Cruz',
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
                    labelText: 'Contraseña (por defecto compartida)',
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
                if (_firebaseMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _signInWithPhone,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Continuar con teléfono'),
                  ),
                ],
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

class _FirebasePhoneDialog extends StatefulWidget {
  const _FirebasePhoneDialog({required this.service});

  final FirebaseAuthService service;

  @override
  State<_FirebasePhoneDialog> createState() => _FirebasePhoneDialogState();
}

class _FirebasePhoneDialogState extends State<_FirebasePhoneDialog> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.service.startPhoneVerification(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _busy = false;
        });
      },
      onVerificationFailed: (error) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = error.message ?? error.code;
        });
      },
      onAutoVerified: (_) {
        if (mounted) Navigator.of(context).pop(true);
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _busy = false;
        });
      },
    );
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (verificationId == null || code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: code,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message ?? error.code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verificar teléfono'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número con código de país',
                hintText: '+56912345678',
              ),
            ),
            if (_verificationId != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Código SMS'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : (_verificationId == null ? _sendCode : _confirmCode),
          child: Text(_verificationId == null ? 'Enviar código' : 'Confirmar'),
        ),
      ],
    );
  }
}
