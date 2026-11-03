import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Helper for picking files from device
class FilePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Pick single image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick multiple images from gallery
  static Future<List<File>> pickMultipleImagesFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      
      return images.map((image) => File(image.path)).toList();
    } catch (e) {
      throw Exception('Failed to pick multiple images: $e');
    }
  }

  /// Take photo with camera
  static Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      throw Exception('Failed to take photo: $e');
    }
  }

  /// Pick document (PDF, etc.)
  static Future<File?> pickDocument() async {
    // Use file_picker package for this
    // FilePickerResult? result = await FilePicker.platform.pickFiles(
    //   type: FileType.custom,
    //   allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    // );
    // if (result == null) return null;
    // return File(result.files.single.path!);
    throw UnimplementedError('Implement with file_picker package');
  }
}