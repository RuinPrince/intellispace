import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';

/// Service responsible for storing and synchronizing student photos across all devices
/// using Supabase Cloud PostgreSQL storage.
class StudentPhotoCloudService {
  static final ApiClient _api = ApiClient();
  static final Map<String, String> _memoryCache = {};
  static bool _initialized = false;

  /// Strips prefixes to standardize barcode / roll number
  static String cleanBarcode(String code) {
    String cleaned = code.trim();
    if (cleaned.startsWith(']C1') || cleaned.startsWith(']c1')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('JC1') || cleaned.startsWith('jc1') || cleaned.startsWith('Jc1')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith(']C') || cleaned.startsWith(']c')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('JC') || cleaned.startsWith('jc')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith(']')) {
      cleaned = cleaned.replaceAll(RegExp(r'^\][A-Za-z0-9]?'), '');
    }

    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 7 && (digitsOnly.startsWith('1235014') || digitsOnly.startsWith('1235025'))) {
      return digitsOnly.substring(1);
    }
    if (digitsOnly.isNotEmpty) return digitsOnly;
    return code.trim().toLowerCase();
  }

  /// Initialize local photo cache from SharedPreferences
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cloud_photo_'));
      for (final key in keys) {
        final barcode = key.replaceFirst('cloud_photo_', '');
        final data = prefs.getString(key);
        if (data != null && data.isNotEmpty) {
          _memoryCache[barcode] = data;
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('StudentPhotoCloudService.init error: $e');
    }
  }

  /// Synchronous memory lookup for immediate UI rendering
  static String? getPhotoSync(String barcode) {
    final clean = cleanBarcode(barcode);
    return _memoryCache[clean];
  }

  /// Retrieve a student photo by barcode (checks memory, local prefs, then Supabase Cloud)
  static Future<String?> getPhoto(String barcode) async {
    final clean = cleanBarcode(barcode);
    if (_memoryCache.containsKey(clean) && _memoryCache[clean]!.isNotEmpty) {
      return _memoryCache[clean];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cloud_photo_$clean');
      if (cached != null && cached.isNotEmpty) {
        _memoryCache[clean] = cached;
        return cached;
      }

      // Fetch from Supabase Cloud
      final res = await _api.get('/notifications?title=eq.STUDENT_AVATAR_$clean&select=message&limit=1');
      if (res is List && res.isNotEmpty) {
        final message = res[0]['message']?.toString() ?? '';
        if (message.isNotEmpty) {
          _memoryCache[clean] = message;
          await prefs.setString('cloud_photo_$clean', message);
          return message;
        }
      }
    } catch (e) {
      debugPrint('StudentPhotoCloudService.getPhoto error for $clean: $e');
    }
    return null;
  }

  /// Uploads or updates a student photo in Supabase Cloud
  /// Accepts base64 data string, network URL, or local file path.
  /// Automatically compresses image before uploading to optimize bandwidth.
  static Future<String?> uploadPhoto({
    required String barcode,
    required String photoDataOrPath,
  }) async {
    final clean = cleanBarcode(barcode);
    if (clean.isEmpty || photoDataOrPath.trim().isEmpty) return null;

    String preparedBase64 = photoDataOrPath.trim();

    try {
      // 1. If it's a local file path, read and compress
      final file = File(photoDataOrPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(
            decoded,
            width: 240,
            height: 280,
            interpolation: img.Interpolation.linear,
          );
          final jpg = img.encodeJpg(resized, quality: 80);
          preparedBase64 = 'data:image/jpeg;base64,${base64Encode(jpg)}';
        } else {
          preparedBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      } else if (!preparedBase64.startsWith('http://') &&
                 !preparedBase64.startsWith('https://') &&
                 !preparedBase64.startsWith('data:image')) {
        // If raw base64 string without data prefix
        if (preparedBase64.length > 50 && !preparedBase64.contains('/')) {
          preparedBase64 = 'data:image/jpeg;base64,$preparedBase64';
        }
      }

      // 2. Cache locally immediately for zero-delay UI responsiveness
      _memoryCache[clean] = preparedBase64;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_photo_$clean', preparedBase64);

      // 3. Sync to Supabase Cloud PostgreSQL
      final existing = await _api.get('/notifications?title=eq.STUDENT_AVATAR_$clean&select=id&limit=1');
      if (existing is List && existing.isNotEmpty) {
        // Update existing record
        await _api.patch('/notifications?title=eq.STUDENT_AVATAR_$clean', body: {
          'message': preparedBase64,
          'is_read': true,
        });
      } else {
        // Insert new record
        await _api.post('/notifications', body: {
          'user_id': 1,
          'notification_type': 'system',
          'title': 'STUDENT_AVATAR_$clean',
          'message': preparedBase64,
          'severity': 'info',
          'is_read': true,
        });
      }

      debugPrint('Student photo successfully uploaded to Supabase cloud for: $clean');
      return preparedBase64;
    } catch (e) {
      debugPrint('Error uploading student photo to cloud: $e');
      return preparedBase64;
    }
  }

  /// Synchronizes ALL student photos from Supabase Cloud to local cache
  /// This ensures every device gets all photos added on any other device.
  static Future<Map<String, String>> syncAllPhotos() async {
    try {
      final res = await _api.get('/notifications?title=like.STUDENT_AVATAR_*&select=title,message');
      if (res is List && res.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final item in res) {
          final title = item['title']?.toString() ?? '';
          final message = item['message']?.toString() ?? '';
          if (title.startsWith('STUDENT_AVATAR_') && message.isNotEmpty) {
            final barcode = cleanBarcode(title.replaceFirst('STUDENT_AVATAR_', ''));
            _memoryCache[barcode] = message;
            await prefs.setString('cloud_photo_$barcode', message);
          }
        }
      }
    } catch (e) {
      debugPrint('StudentPhotoCloudService.syncAllPhotos error: $e');
    }
    return Map.unmodifiable(_memoryCache);
  }

  /// Deletes photo from cloud and local cache
  static Future<void> deletePhoto(String barcode) async {
    final clean = cleanBarcode(barcode);
    _memoryCache.remove(clean);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cloud_photo_$clean');
      await _api.delete('/notifications?title=eq.STUDENT_AVATAR_$clean');
    } catch (e) {
      debugPrint('StudentPhotoCloudService.deletePhoto error: $e');
    }
  }
}
