import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherResult {
  final int weatherCode;
  final String weatherLabel;
  final double tempC;
  final double multiplier;

  const WeatherResult({
    required this.weatherCode,
    required this.weatherLabel,
    required this.tempC,
    required this.multiplier,
  });
}

class WeatherService {
  Future<WeatherResult?> fetchForCoordinate(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,weather_code',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final code = (current['weather_code'] as num).toInt();
      final temp = (current['temperature_2m'] as num).toDouble();

      return WeatherResult(
        weatherCode: code,
        weatherLabel: _label(code),
        tempC: temp,
        multiplier: _multiplier(code),
      );
    } catch (_) {
      return null;
    }
  }

  static String _label(int code) {
    if (code == 0) return 'Clear';
    if (code == 1) return 'Mostly Clear';
    if (code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code == 61) return 'Light Rain';
    if (code == 63 || code == 80 || code == 81) return 'Moderate Rain';
    if (code == 65 || code == 82) return 'Heavy Rain';
    if (code == 71 || code == 73) return 'Light Snow';
    if (code == 75 || code == 77) return 'Heavy Snow';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Heavy Thunderstorm';
    return 'Unknown';
  }

  static double _multiplier(int code) {
    if (code >= 0 && code <= 2) return 1.00;
    if (code == 3 || code == 45 || code == 48) return 1.05;
    if ((code >= 51 && code <= 57) || code == 61) return 1.10;
    if (code == 63 || code == 80 || code == 81) return 1.15;
    if (code == 65 || code == 82 || (code >= 95 && code <= 99)) return 1.25;
    if (code >= 71 && code <= 77) return 1.20;
    return 1.00;
  }
}