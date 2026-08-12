import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _session;
  bool _checkingProfile = false;
  bool _allowlisted = false;
  bool _profileMissing = false;
  Object? _profileCheckError;
  int _checkGeneration = 0;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      _session = state.session;
      _checkProfile(state.session);
    });
    _checkProfile(_session);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkProfile(Session? session) async {
    final generation = ++_checkGeneration;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _checkingProfile = false;
        _allowlisted = false;
        _profileMissing = false;
        _profileCheckError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _checkingProfile = true;
        _allowlisted = false;
        _profileMissing = false;
        _profileCheckError = null;
      });
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', session.user.id)
          .maybeSingle();
      if (!mounted || generation != _checkGeneration) return;
      setState(() {
        _checkingProfile = false;
        _allowlisted = row != null;
        _profileMissing = row == null;
      });
    } on Exception catch (error) {
      if (!mounted || generation != _checkGeneration) return;
      setState(() {
        _checkingProfile = false;
        _profileCheckError = error;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const LoginScreen();
    }
    if (_checkingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowlisted) {
      return widget.child;
    }
    return _AccessBlockedScreen(
      profileMissing: _profileMissing,
      error: _profileCheckError,
      onRetry: () => _checkProfile(_session),
      onSignOut: _signOut,
    );
  }
}

class _AccessBlockedScreen extends StatelessWidget {
  const _AccessBlockedScreen({
    required this.profileMissing,
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final bool profileMissing;
  final Object? error;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isMissing = error == null && profileMissing;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMissing ? Icons.lock_outline : Icons.cloud_off_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                isMissing
                    ? 'Cuenta no habilitada'
                    : 'No se pudo validar la cuenta',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isMissing
                    ? 'Esta cuenta no pertenece a los cuatro participantes de EnfermiCambio. Pide al administrador que la habilite.'
                    : 'Comprueba la conexión e inténtalo nuevamente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!isMissing)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              FilledButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
