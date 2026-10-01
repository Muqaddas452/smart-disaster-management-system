import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Icon Cache: Stream rebuilds par icons dobara create na hoon
final Map<String, BitmapDescriptor> markerIconCache = {};

// Material Icon ko Canvas par draw karke BitmapDescriptor banane ka helper
Future<BitmapDescriptor> createCustomMarkerIcon(
    IconData iconData,
    Color bgColor,
    Color iconColor,
    {int size = 110}
    ) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final double radius = size / 2;

  // Background Circle
  final Paint bgPaint = Paint()..color = bgColor;
  canvas.drawCircle(Offset(radius, radius), radius, bgPaint);

  // Border Circle
  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;
  canvas.drawCircle(Offset(radius, radius), radius - 3, borderPaint);

  // Material Icon Rendering
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  textPainter.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: size * 0.55,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      color: iconColor,
    ),
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(radius - (textPainter.width / 2), radius - (textPainter.height / 2)),
  );

  final ui.Image image = await pictureRecorder.endRecording().toImage(size, size);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
      return Icons.thunderstorm;
    case 'snowfall':
      return Icons.ac_unit;
    case 'fire':
      return Icons.local_fire_department;
    case 'accident':
      return Icons.car_crash;
    case 'heatwave':
      return Icons.wb_sunny;
    default:
      return Icons.warning_amber_rounded;
  }
}