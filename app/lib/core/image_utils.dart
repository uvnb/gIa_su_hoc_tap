import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Xử lý ảnh – chạy trong isolate bằng compute() để không giật giao diện trên máy yếu (mục 14.3).

/// Nén ảnh: cạnh dài ≤ 1280px, JPEG 80% (~150–300KB).
Uint8List shrinkJpeg(Uint8List raw, {int maxSide = 1280, int quality = 80}) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  final oriented = img.bakeOrientation(decoded);
  final img.Image resized;
  if (oriented.width >= oriented.height) {
    resized = oriented.width > maxSide ? img.copyResize(oriented, width: maxSide) : oriented;
  } else {
    resized = oriented.height > maxSide ? img.copyResize(oriented, height: maxSide) : oriented;
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}

/// Tham số cho compute(): ảnh + vùng cắt (tỉ lệ 0..1).
class CropRequest {
  final Uint8List bytes;
  final double left, top, right, bottom;
  const CropRequest(this.bytes, this.left, this.top, this.right, this.bottom);
}

/// FR-12: cắt vùng câu muốn làm rồi nén.
Uint8List cropAndShrink(CropRequest r) {
  final decoded = img.decodeImage(r.bytes);
  if (decoded == null) return r.bytes;
  final o = img.bakeOrientation(decoded);
  final int x = (r.left * o.width).round().clamp(0, o.width - 1).toInt();
  final int y = (r.top * o.height).round().clamp(0, o.height - 1).toInt();
  final int w = ((r.right - r.left) * o.width).round().clamp(1, o.width - x).toInt();
  final int h = ((r.bottom - r.top) * o.height).round().clamp(1, o.height - y).toInt();
  final cropped = img.copyCrop(o, x: x, y: y, width: w, height: h);
  return shrinkJpeg(Uint8List.fromList(img.encodeJpg(cropped, quality: 92)));
}

/// Kết quả kiểm tra chất lượng ảnh (FR-11).
class ImageQuality {
  final bool dark;
  final bool blurry;
  final double brightness;
  final double sharpness;
  const ImageQuality(this.dark, this.blurry, this.brightness, this.sharpness);
  bool get ok => !dark && !blurry;
}

/// Độ sáng trung bình + phương sai Laplacian (độ nét) trên ảnh thu nhỏ 320px.
/// Ngưỡng là kinh nghiệm – chỉnh lại sau khi thử với ảnh thật trên Tab 10 Edu.
ImageQuality checkQuality(Uint8List bytes) {
  const darkThreshold = 60.0;
  const blurThreshold = 45.0;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const ImageQuality(true, true, 0, 0);
  final small = img.grayscale(img.copyResize(img.bakeOrientation(decoded), width: 320));
  final w = small.width, h = small.height;
  final lum = List<double>.filled(w * h, 0);
  var sum = 0.0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = small.getPixel(x, y).r.toDouble();
      lum[y * w + x] = v;
      sum += v;
    }
  }
  final mean = sum / (w * h);
  var lapSum = 0.0, lapSq = 0.0, n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final c = lum[y * w + x];
      final l = 4 * c - lum[y * w + x - 1] - lum[y * w + x + 1] - lum[(y - 1) * w + x] - lum[(y + 1) * w + x];
      lapSum += l;
      lapSq += l * l;
      n++;
    }
  }
  final lapMean = lapSum / n;
  final variance = lapSq / n - lapMean * lapMean;
  return ImageQuality(mean < darkThreshold, variance < blurThreshold, mean, variance);
}

Future<Uint8List> shrinkInBackground(Uint8List raw) => compute(shrinkJpeg, raw);
Future<Uint8List> cropInBackground(CropRequest r) => compute(cropAndShrink, r);
Future<ImageQuality> qualityInBackground(Uint8List raw) => compute(checkQuality, raw);
