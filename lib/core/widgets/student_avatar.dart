import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/student_photo_cloud_service.dart';

/// Reusable student avatar widget that cleanly displays:
/// - Base64 encoded images (data:image or raw base64)
/// - Local file paths
/// - Network URLs
/// - Synced cloud photos via barcode
/// - Fallback letter initial or icon
class StudentAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? studentName;
  final String? barcode;
  final double? width;
  final double? height;
  final double? radius;
  final BorderRadius? borderRadius;
  final Border? border;
  final BoxFit fit;

  const StudentAvatar({
    super.key,
    this.avatarUrl,
    this.studentName,
    this.barcode,
    this.width,
    this.height,
    this.radius,
    this.borderRadius,
    this.border,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius;
    final effectiveWidth = width ?? (effectiveRadius != null ? effectiveRadius * 2 : 50);
    final effectiveHeight = height ?? (effectiveRadius != null ? effectiveRadius * 2 : 50);
    final effectiveBorderRadius = borderRadius ??
        (effectiveRadius != null
            ? BorderRadius.circular(effectiveRadius)
            : BorderRadius.circular(10));

    Widget imageWidget = _buildFallback(context);

    String? effectiveUrl = (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
        ? avatarUrl!.trim()
        : null;

    if ((effectiveUrl == null || effectiveUrl.isEmpty) && barcode != null && barcode!.trim().isNotEmpty) {
      effectiveUrl = StudentPhotoCloudService.getPhotoSync(barcode!);
    }

    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      final url = effectiveUrl;

      try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          imageWidget = Image.network(
            url,
            width: effectiveWidth,
            height: effectiveHeight,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          );
        } else if (url.startsWith('data:image') || _isBase64(url)) {
          final cleanBase64 = url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
          imageWidget = Image.memory(
            bytes,
            width: effectiveWidth,
            height: effectiveHeight,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          );
        } else {
          final file = File(url);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: effectiveWidth,
              height: effectiveHeight,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallback(context),
            );
          } else if (barcode != null && barcode!.trim().isNotEmpty) {
            // Local file doesn't exist on this device - try cloud photo
            final cloudPhoto = StudentPhotoCloudService.getPhotoSync(barcode!);
            if (cloudPhoto != null && cloudPhoto.isNotEmpty && cloudPhoto != url) {
              final cleanBase64 = cloudPhoto.contains(',') ? cloudPhoto.split(',').last : cloudPhoto;
              final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
              imageWidget = Image.memory(
                bytes,
                width: effectiveWidth,
                height: effectiveHeight,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _buildFallback(context),
              );
            }
          }
        }
      } catch (_) {
        imageWidget = _buildFallback(context);
      }
    }

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  bool _isBase64(String str) {
    if (str.startsWith('data:image')) return true;
    if (str.startsWith('/') || str.startsWith('file:') || str.contains('\\') || str.startsWith('http')) return false;
    if (str.length < 50) return false;
    return RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(str.replaceAll('\n', '').replaceAll('\r', '').trim());
  }

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (studentName != null && studentName!.trim().isNotEmpty)
        ? studentName!.trim().substring(0, 1).toUpperCase()
        : '';

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: initial.isNotEmpty
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: (height ?? 50) * 0.45,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.person,
                size: (height ?? 50) * 0.6,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
      ),
    );
  }
}
