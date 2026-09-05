import 'package:flutter/material.dart';
import '../map/google_map_widget.dart';

class MapPanel extends StatelessWidget {
  const MapPanel({super.key});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: 360,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: const GoogleMapWidget(),
      ),
    );
  }
}