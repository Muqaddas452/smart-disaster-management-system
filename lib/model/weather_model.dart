import 'package:cloud_firestore/cloud_firestore.dart';

class WeatherModel {
  final String id;
  final double temperature;
  final int humidity;
  final int pressure;
  final double rainfall;
  final double windSpeed;
  final String district;
  final String disaster;
  final String risk;
  final String time;

  WeatherModel({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.rainfall,
    required this.windSpeed,
    required this.district,
    required this.disaster,
    required this.risk,
    required this.time,
  });

  factory WeatherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return WeatherModel(
      id: doc.id,
      temperature: (data['temperature'] ?? 0).toDouble(),
      humidity: (data['humidity'] ?? 0),
      pressure: (data['pressure'] ?? 0),
      rainfall: (data['rainfall'] ?? 0).toDouble(),
      windSpeed: (data['wind_speed'] ?? 0).toDouble(),
      district: data['district'] ?? '',
      disaster: data['disaster'] ?? '',
      risk: data['risk'] ?? '',
      time: data['time'] ?? '',
    );
  }
}