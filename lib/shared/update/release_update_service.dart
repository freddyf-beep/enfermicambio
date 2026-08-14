import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_environment.dart';

enum ReleaseUpdateState {
  idle,
  checking,
  current,
  available,
  unavailable,
  error,
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.platform,
    required this.version,
    required this.build,
    required this.fileName,
    required this.downloadUrl,
    this.sha256,
  });

  final String platform;
  final String version;
  final int build;
  final String fileName;
  final String downloadUrl;
  final String? sha256;

  static ReleaseInfo? fromManifest(
    Map<String, dynamic> manifest,
    String platform,
  ) {
    final platforms = manifest['platforms'];
    final raw = platforms is Map ? platforms[platform] : manifest[platform];
    if (raw is! Map) return null;

    final version = (raw['version'] ?? manifest['version'])?.toString();
    final fileName = raw['fileName']?.toString();
    final downloadUrl = (raw['downloadUrl'] ?? raw['url'])?.toString();
    if (version == null ||
        version.isEmpty ||
        fileName == null ||
        fileName.isEmpty) {
      return null;
    }
    if (downloadUrl == null || downloadUrl.isEmpty) return null;

    final buildValue = raw['build'] ?? manifest['build'];
    final build = buildValue is num
        ? buildValue.toInt()
        : int.tryParse(buildValue?.toString() ?? '') ?? 0;
    final sha256 = raw['sha256']?.toString();

    return ReleaseInfo(
      platform: platform,
      version: version,
      build: build,
      fileName: fileName,
      downloadUrl: downloadUrl,
      sha256: sha256?.isEmpty == true ? null : sha256,
    );
  }
}

class ReleaseUpdateSnapshot {
  const ReleaseUpdateSnapshot({
    this.state = ReleaseUpdateState.idle,
    this.release,
    this.message,
  });

  final ReleaseUpdateState state;
  final ReleaseInfo? release;
  final String? message;
}

class ReleaseUpdateService {
  ReleaseUpdateService._();

  static final ReleaseUpdateService _instance = ReleaseUpdateService._();

  static ReleaseUpdateService ensure() => _instance;

  final ValueNotifier<ReleaseUpdateSnapshot> status = ValueNotifier(
    const ReleaseUpdateSnapshot(),
  );
  bool _checking = false;

  Future<void> check() async {
    if (_checking) return;
    final manifestUrl = AppEnvironment.releaseManifestUrl.trim();
    if (manifestUrl.isEmpty) {
      status.value = const ReleaseUpdateSnapshot(
        state: ReleaseUpdateState.unavailable,
      );
      return;
    }

    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || !uri.hasScheme) {
      status.value = const ReleaseUpdateSnapshot(
        state: ReleaseUpdateState.error,
        message: 'La dirección de actualizaciones no es válida.',
      );
      return;
    }

    _checking = true;
    status.value = const ReleaseUpdateSnapshot(
      state: ReleaseUpdateState.checking,
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException('Manifest inválido');
      final platform = _platformKey();
      final release = ReleaseInfo.fromManifest(
        Map<String, dynamic>.from(decoded),
        platform,
      );
      if (release == null) {
        status.value = const ReleaseUpdateSnapshot(
          state: ReleaseUpdateState.unavailable,
          message: 'No hay una versión para esta plataforma.',
        );
        return;
      }

      final newer = isNewer(
        currentVersion: AppEnvironment.appVersion,
        currentBuild: AppEnvironment.appBuild,
        remoteVersion: release.version,
        remoteBuild: release.build,
      );
      status.value = ReleaseUpdateSnapshot(
        state: newer
            ? ReleaseUpdateState.available
            : ReleaseUpdateState.current,
        release: release,
      );
    } on Exception catch (error) {
      status.value = ReleaseUpdateSnapshot(
        state: ReleaseUpdateState.error,
        message: _shortError(error),
      );
    } finally {
      _checking = false;
    }
  }

  Future<bool> openDownload(ReleaseInfo release) async {
    final uri = Uri.tryParse(release.downloadUrl);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static bool isNewer({
    required String currentVersion,
    required int currentBuild,
    required String remoteVersion,
    required int remoteBuild,
  }) {
    final versionComparison = _compareVersions(remoteVersion, currentVersion);
    if (versionComparison != 0) return versionComparison > 0;
    return remoteBuild > currentBuild;
  }

  static String _platformKey() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'other',
    };
  }

  static int _compareVersions(String left, String right) {
    final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final aValue = index < a.length ? a[index] : 0;
      final bValue = index < b.length ? b[index] : 0;
      if (aValue != bValue) return aValue.compareTo(bValue);
    }
    return 0;
  }

  static String _shortError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.length > 120 ? '${message.substring(0, 117)}…' : message;
  }
}
