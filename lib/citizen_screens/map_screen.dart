import 'package:flutter/material.dart';
import '../widgets/map/disaster_map.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: null,
      body: SafeArea(
        child: DisasterMap(),
      ),
    );
  }
}