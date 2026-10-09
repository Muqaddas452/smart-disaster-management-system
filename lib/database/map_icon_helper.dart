import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// 1. Circle ke baghair direct clean Material Icon banane ka function
Future<BitmapDescriptor> createDirectIconMarker(
    IconData iconData,
    Color color,
    {int size = 30}
    ) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);


  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  textPainter.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: size.toDouble(),
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      color: color,
    ),
  );

  textPainter.layout();
  textPainter.paint(canvas, Offset.zero);

  final ui.Image image = await pictureRecorder.endRecording().toImage(size, size);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
}

// 2. Agar aapne assets mein koi icon download kiya hai (jaise shelter ya alert ki image)
Future<BitmapDescriptor> createAssetIconMarker(
    String assetPath, {
      int width = 40,
      int height = 30,
    }) async {
  final ByteData data = await rootBundle.load('assets/icons/alert_icon.jpeg');
  ui.Codec codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: width,
    targetHeight: height,
  );
  ui.FrameInfo fi = await codec.getNextFrame();
  ByteData? byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
}

// Task Type ke hisab se Icon Return karta hai
IconData getTaskTypeIcon(String type) {
  switch (type.toLowerCase().trim()) {
    case 'heavy rains':
    case 'rain':
      return Icons.water_drop;
    case 'flood':
      return Icons.tsunami;
    case 'storms':
    case 'thunderstorm':
    case 'storm':
      return Icons.thunderstorm;
    case 'snowfall':
      return Icons.ac_unit;
    case 'fire':
      return Icons.local_fire_department;
    case 'accident':
      return Icons.car_crash;
    case 'heatwave':
      return Icons.wb_sunny; // Sun icon for heatwave
    default:
      return Icons.warning_amber_rounded;
  }
}

// ─────────────────────────────────────────────────────────────
// 3. Naam + status wala marker (jaise "Ali · Enroute").
// Google Maps mein marker par text hamesha-dikhane ka koi seedha raasta
// nahi, is liye text ko pill ki shakal mein bitmap bana kar marker icon
// banate hain. 3x resolution par draw hota hai taake sharp dikhe.
// ─────────────────────────────────────────────────────────────
Future<BitmapDescriptor> createLabelMarker(String text, Color color) async {
  const double scale = 3.0;
  const double padH = 10 * scale;
  const double padV = 6 * scale;
  const double tip = 8 * scale;

  final TextPainter tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12 * scale,
        fontWeight: FontWeight.bold,
      ),
    ),
    maxLines: 1,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 190 * scale);

  final double pillW = tp.width + padH * 2;
  final double pillH = tp.height + padV * 2;
  final double totalH = pillH + tip;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  final RRect pill = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, pillW, pillH),
    Radius.circular(pillH / 2),
  );
  final Path pointer = Path()
    ..moveTo(pillW / 2 - tip * 0.8, pillH - 1)
    ..lineTo(pillW / 2, totalH)
    ..lineTo(pillW / 2 + tip * 0.8, pillH - 1)
    ..close();

  final Paint fill = Paint()..color = color;
  canvas.drawRRect(pill, fill);
  canvas.drawPath(pointer, fill);
  canvas.drawRRect(
    pill,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale,
  );
  tp.paint(canvas, Offset(padH, padV));

  final ui.Image image =
  await recorder.endRecording().toImage(pillW.ceil(), totalH.ceil());
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: scale);
}

/// createLabelMarker ka cache. Marker build() mein synchronously chahiye hote
/// hain, is liye: lookup() se cached icon lo; na mile to prepare() chala do
/// (async banata hai, phir onReady() se screen rebuild karwao).
class LabelMarkerCache {
  static final Map<String, BitmapDescriptor> _cache = {};
  static final Set<String> _pending = {};

  static BitmapDescriptor? lookup(String key) => _cache[key];

  static Future<void> prepare(
      String key, String text, Color color, VoidCallback onReady) async {
    if (_cache.containsKey(key) || !_pending.add(key)) return;
    try {
      _cache[key] = await createLabelMarker(text, color);
      onReady();
    } catch (_) {
      // icon na bane to caller default marker use karta rahega
    } finally {
      _pending.remove(key);
    }
  }
}
