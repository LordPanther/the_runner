// lib/data/services/image_compression_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Service for compressing images before upload
class ImageCompressionService {
  /// Compress image file
  static Future<File> compressImage(File imageFile, {int quality = 85}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      if (result == null) {
        return imageFile;
      }
      
      return File(result.path);
    } catch (e) {
      debugPrint('Failed to compress image: $e');
      return imageFile;
    }
  }
  
  /// Get image size in bytes
  static Future<int> getImageSize(File imageFile) async {
    return await imageFile.length();
  }
  
  /// Check if image needs compression
  static Future<bool> needsCompression(File imageFile, {int maxSizeMB = 2}) async {
    final size = await imageFile.length();
    return size > maxSizeMB * 1024 * 1024;
  }
}