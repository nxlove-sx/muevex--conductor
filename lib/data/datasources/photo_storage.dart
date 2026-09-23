import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;

enum PhotoBucket { driver, vehicle }

extension PhotoBucketName on PhotoBucket {
  String get name => switch (this) {
        PhotoBucket.driver => 'profiles',
        PhotoBucket.vehicle => 'vehicles',
      };
}

class PhotoStorage {
  static final _picker = ImagePicker();

  static Future<XFile?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    return file;
  }

  static Future<String> upload(
    PhotoBucket bucket,
    String ownerId,
    XFile file,
  ) async {
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext) ? ext : 'jpg';
    // Limite de los buckets profiles/vehicles: 5 MB.
    if (await File(file.path).length() > 5 * 1024 * 1024) {
      throw StateError('La foto supera el máximo de 5 MB.');
    }
    final path = '$ownerId/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await db.supabase.storage
        .from(bucket.name)
        .upload(path, File(file.path), fileOptions: FileOptions(upsert: false));
    return db.supabase.storage.from(bucket.name).getPublicUrl(path);
  }
}