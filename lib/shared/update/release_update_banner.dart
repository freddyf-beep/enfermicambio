import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/app_theme.dart';
import 'release_update_service.dart';

class ReleaseUpdateBanner extends StatefulWidget {
  const ReleaseUpdateBanner({super.key});

  @override
  State<ReleaseUpdateBanner> createState() => _ReleaseUpdateBannerState();
}

class _ReleaseUpdateBannerState extends State<ReleaseUpdateBanner> {
  late final ReleaseUpdateService _service;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _service = ReleaseUpdateService.ensure();
    unawaited(_service.check());
  }

  Future<void> _download(ReleaseInfo release) async {
    setState(() {
      _opening = true;
    });
    final opened = await _service.openDownload(release);
    if (!mounted) return;
    setState(() {
      _opening = false;
    });
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace de actualización.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReleaseUpdateSnapshot>(
      valueListenable: _service.status,
      builder: (context, snapshot, _) {
        final release = snapshot.release;
        if (snapshot.state != ReleaseUpdateState.available || release == null) {
          return const SizedBox.shrink();
        }
        return Card(
          color: AppColors.primaryLight.withValues(alpha: 0.14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.system_update_alt,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actualización disponible',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Versión ${release.version} · build ${release.build}',
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _opening ? null : () => _download(release),
                  child: _opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Actualizar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
