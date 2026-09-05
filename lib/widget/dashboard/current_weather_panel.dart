import 'package:flutter/material.dart';

import '../../model/weather_model.dart';
import '../../services/weather_service.dart';

class CurrentWeatherPanel extends StatelessWidget {
  const CurrentWeatherPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WeatherModel>>(
      stream: WeatherService().getWeather(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: SizedBox(
              height: 320,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: SizedBox(
              height: 320,
              child: Center(
                child: Text(
                  "Error loading weather data",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Card(
            child: SizedBox(
              height: 320,
              child: Center(
                child: Text(
                  "No Weather Data Available",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        final weather = snapshot.data!.first;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Weather",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(
                    Icons.thermostat,
                    color: Colors.red,
                  ),
                  title: const Text("Temperature"),
                  trailing: Text(
                    "${weather.temperature.toStringAsFixed(1)}°C",
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.water_drop,
                    color: Colors.blue,
                  ),
                  title: const Text("Humidity"),
                  trailing: Text(
                    "${weather.humidity}%",
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.cloud,
                    color: Colors.indigo,
                  ),
                  title: const Text("Rainfall"),
                  trailing: Text(
                    "${weather.rainfall.toStringAsFixed(1)} mm",
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.air,
                    color: Colors.green,
                  ),
                  title: const Text("Wind Speed"),
                  trailing: Text(
                    "${weather.windSpeed.toStringAsFixed(1)} km/h",
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.speed,
                    color: Colors.orange,
                  ),
                  title: const Text("Pressure"),
                  trailing: Text(
                    "${weather.pressure} hPa",
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}