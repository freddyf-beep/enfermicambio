import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves a private Storage reference such as `avatars/user/file.jpg` into
/// a short-lived signed URL. Public URLs are returned unchanged so this also
/// works with legacy records created before private media was introduced.
class SupabaseStorageReferenceResolver {
  const SupabaseStorageReferenceResolver({required this.client});

  final SupabaseClient client;

  Future<String?> resolve(String? reference, {int expiresIn = 3600}) async {
    final value = reference?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final separator = value.indexOf('/');
    if (separator <= 0 || separator == value.length - 1) return null;
    final bucket = value.substring(0, separator);
    final path = value.substring(separator + 1);
    try {
      return await client.storage.from(bucket).createSignedUrl(path, expiresIn);
    } on Object {
      return null;
    }
  }
}
