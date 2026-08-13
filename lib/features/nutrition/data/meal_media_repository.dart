import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class MealMediaUpload {
  const MealMediaUpload({required this.bucket, required this.path});

  final String bucket;
  final String path;

  String get reference => '$bucket/$path';
}

/// Uploads compressed picker output to the private bucket. Callers retain the
/// local file and can safely offer a retry if all attempts fail.
class MealMediaRepository {
  const MealMediaRepository({required this._client});

  final SupabaseClient _client;

  Future<MealMediaUpload> uploadWithRetry({
    required String userId,
    required String filePath,
    required String contentType,
    int attempts = 2,
  }) async {
    final extension = _extensionFor(contentType, filePath);
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}$extension';
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        await _client.storage
            .from('meal-media')
            .upload(
              path,
              File(filePath),
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: attempt > 0,
              ),
            );
        return MealMediaUpload(bucket: 'meal-media', path: path);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw StateError(
      'No se pudo subir la foto tras $attempts intentos: $lastError',
    );
  }

  Future<void> remove(MealMediaUpload upload) async {
    await _client.storage.from(upload.bucket).remove([upload.path]);
  }

  String _extensionFor(String contentType, String filePath) {
    if (contentType.contains('png')) return '.png';
    if (contentType.contains('heic')) return '.heic';
    final sourceExtension = RegExp(
      r'\.(jpe?g|png|heic)$',
      caseSensitive: false,
    ).firstMatch(filePath)?.group(0);
    return sourceExtension?.toLowerCase() ?? '.jpg';
  }
}
