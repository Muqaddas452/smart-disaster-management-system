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