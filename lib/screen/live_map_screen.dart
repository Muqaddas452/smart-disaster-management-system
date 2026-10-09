import 'package:flutter/material.dart';
import '../widget/map/google_map_widget.dart';

class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: GoogleMapWidget(),
    );
  }
}