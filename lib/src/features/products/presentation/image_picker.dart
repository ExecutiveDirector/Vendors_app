import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:dio/dio.dart';

/// Result of image validation
class ImageValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double? fileSizeMB;

  ImageValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fileSizeMB,
  });
}

/// Singleton ImagePickerService
class ImagePickerService {
  // Singleton pattern
  static final ImagePickerService _instance = ImagePickerService._internal();
  factory ImagePickerService() => _instance;
  ImagePickerService._internal();

  final picker.ImagePicker _picker = picker.ImagePicker();

  // Default configuration
  static const double defaultMaxWidth = 1920;
  static const double defaultMaxHeight = 1080;
  static const int defaultImageQuality = 85;
  static const double defaultMaxSizeMB = 5.0;
  static const List<String> defaultAllowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];

  /// Pick a single image from gallery
  Future<picker.XFile?> pickFromGallery({
    double maxWidth = defaultMaxWidth,
    double maxHeight = defaultMaxHeight,
    int imageQuality = defaultImageQuality,
  }) async {
    try {
      return await _picker.pickImage(
        source: picker.ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    } catch (e) {
      debugPrint('❌ Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  Future<List<picker.XFile>> pickMultipleFromGallery({
    double maxWidth = defaultMaxWidth,
    double maxHeight = defaultMaxHeight,
    int imageQuality = defaultImageQuality,
    int? limit,
  }) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (limit != null && images.length > limit) {
        return images.sublist(0, limit);
      }
      return images;
    } catch (e) {
      debugPrint('❌ Error picking multiple images: $e');
      return [];
    }
  }

  /// Take a photo with the camera
  Future<picker.XFile?> takePhoto({
    double maxWidth = defaultMaxWidth,
    double maxHeight = defaultMaxHeight,
    int imageQuality = defaultImageQuality,
    picker.CameraDevice preferredCamera = picker.CameraDevice.rear,
  }) async {
    try {
      return await _picker.pickImage(
        source: picker.ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCamera,
      );
    } catch (e) {
      debugPrint('❌ Error taking photo: $e');
      return null;
    }
  }

  /// Pick video from gallery
  Future<picker.XFile?> pickVideo({Duration? maxDuration}) async {
    try {
      return await _picker.pickVideo(
        source: picker.ImageSource.gallery,
        maxDuration: maxDuration,
      );
    } catch (e) {
      debugPrint('❌ Error picking video: $e');
      return null;
    }
  }

  /// Record video using camera
  Future<picker.XFile?> recordVideo({
    Duration? maxDuration,
    picker.CameraDevice preferredCamera = picker.CameraDevice.rear,
  }) async {
    try {
      return await _picker.pickVideo(
        source: picker.ImageSource.camera,
        maxDuration: maxDuration,
        preferredCameraDevice: preferredCamera,
      );
    } catch (e) {
      debugPrint('❌ Error recording video: $e');
      return null;
    }
  }

  /// Show bottom sheet (Camera / Gallery)
  Future<dynamic> showImageSourceBottomSheet(
    BuildContext context, {
    bool allowMultiple = false,
  }) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceBottomSheet(
        allowMultiple: allowMultiple,
      ),
    );

    // Return single or multiple images properly
    if (result is picker.XFile || result is List<picker.XFile>) {
      return result;
    }
    return null;
  }

  /// Show dialog (Camera / Gallery)
  Future<picker.XFile?> showImageSourceDialog(BuildContext context) async {
    return showDialog<picker.XFile?>(
      context: context,
      builder: (_) => const _ImageSourceDialog(),
    );
  }

  /// Validate image file (extension, size, existence)
  Future<ImageValidationResult> validateImage(
    picker.XFile file, {
    double maxSizeMB = defaultMaxSizeMB,
    List<String> allowedExtensions = defaultAllowedExtensions,
  }) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        return ImageValidationResult(
          isValid: false,
          errorMessage:
              'Invalid file type. Allowed: ${allowedExtensions.join(", ")}',
        );
      }

      final bytes = await file.length();
      final sizeMB = bytes / (1024 * 1024);
      if (sizeMB > maxSizeMB) {
        return ImageValidationResult(
          isValid: false,
          errorMessage:
              'File too large (${sizeMB.toStringAsFixed(2)} MB). Max: ${maxSizeMB} MB',
        );
      }

      if (!await File(file.path).exists()) {
        return ImageValidationResult(
          isValid: false,
          errorMessage: 'File not found',
        );
      }

      return ImageValidationResult(isValid: true, fileSizeMB: sizeMB);
    } catch (e) {
      return ImageValidationResult(isValid: false, errorMessage: e.toString());
    }
  }

  /// Upload single image to server
  Future<String?> uploadImage({
    required picker.XFile image,
    required String uploadUrl,
    required Dio dio,
    String fieldName = 'image',
    Map<String, dynamic>? additionalData,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      debugPrint('📤 Uploading image: ${image.name}');
      final formData = FormData.fromMap({
        fieldName:
            await MultipartFile.fromFile(image.path, filename: image.name),
        if (additionalData != null) ...additionalData,
      });

      final response = await dio.post(
        uploadUrl,
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.data is Map) {
        return (response.data['url'] ??
                response.data['image_url'] ??
                response.data['file_url'] ??
                response.data['path'])
            ?.toString();
      } else if (response.data is String) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return null;
    }
  }

  /// Upload multiple images sequentially
  Future<List<String>> uploadMultipleImages({
    required List<picker.XFile> images,
    required String uploadUrl,
    required Dio dio,
    String fieldName = 'image',
    Map<String, dynamic>? additionalData,
    void Function(int currentIndex, int total)? onBatchProgress,
  }) async {
    final uploaded = <String>[];
    for (var i = 0; i < images.length; i++) {
      onBatchProgress?.call(i + 1, images.length);
      final url = await uploadImage(
        image: images[i],
        uploadUrl: uploadUrl,
        dio: dio,
        fieldName: fieldName,
        additionalData: additionalData,
      );
      if (url != null) uploaded.add(url);
    }
    return uploaded;
  }

  /// Delete local file
  Future<bool> deleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting: $e');
      return false;
    }
  }

  /// Build network image widget
  Widget buildImageWidget({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    Widget child;
    if (imageUrl == null || imageUrl.isEmpty) {
      child = errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
    } else {
      child = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : (placeholder ?? const Center(child: CircularProgressIndicator())),
        errorBuilder: (context, error, stack) =>
            errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    return borderRadius != null
        ? ClipRRect(borderRadius: borderRadius, child: child)
        : child;
  }

  /// Build local image widget from XFile
  Widget buildLocalImageWidget({
    required picker.XFile image,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    final child = Image.file(
      File(image.path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) =>
          const Icon(Icons.broken_image, color: Colors.grey),
    );
    return borderRadius != null
        ? ClipRRect(borderRadius: borderRadius, child: child)
        : child;
  }
}

// /// Image validation result class
// class ImageValidationResult {
//   final bool isValid;
//   final String? errorMessage;
//   final double? fileSizeMB;

//   ImageValidationResult({
//     required this.isValid,
//     this.errorMessage,
//     this.fileSizeMB,
//   });
// }

/// Image source bottom sheet widget
/// Image source bottom sheet widget
class _ImageSourceBottomSheet extends StatelessWidget {
  final bool allowMultiple;

  const _ImageSourceBottomSheet({
    this.allowMultiple = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = ImagePickerService();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Gallery option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library,
                      color: Colors.blue, size: 28),
                ),
                title: const Text('Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(allowMultiple
                    ? 'Choose multiple photos'
                    : 'Choose from your photos'),
                onTap: () async {
                  if (allowMultiple) {
                    final images = await service.pickMultipleFromGallery();
                    if (context.mounted) Navigator.pop(context, images);
                  } else {
                    final image = await service.pickFromGallery();
                    if (context.mounted) Navigator.pop(context, image);
                  }
                },
              ),

              // ✅ Camera option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.green, size: 28),
                ),
                title: const Text('Camera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Take a new photo'),
                onTap: () async {
                  final image = await service.takePhoto();
                  if (context.mounted) Navigator.pop(context, image);
                },
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image source dialog widget
class _ImageSourceDialog extends StatelessWidget {
  const _ImageSourceDialog();

  @override
  Widget build(BuildContext context) {
    final service = ImagePickerService();

    return AlertDialog(
      title: const Text('Choose Image Source'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blue),
            title: const Text('Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final image = await service.pickFromGallery();
              if (context.mounted) {
                Navigator.pop(context, image);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text('Camera'),
            onTap: () async {
              Navigator.pop(context);
              final image = await service.takePhoto();
              if (context.mounted) {
                Navigator.pop(context, image);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
