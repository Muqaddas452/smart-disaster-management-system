import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/weather_model.dart';

class WeatherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<WeatherModel>> getWeather() {
    return _firestore
        .collection("alerts")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => WeatherModel.fromFirestore(doc))
          .toList(),
    );
  }
}