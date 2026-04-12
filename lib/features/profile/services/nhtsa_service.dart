import 'dart:convert';

import 'package:http/http.dart' as http;

class NhtsaService {
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  /// Fetches all car makes. Returns sorted list or throws on failure.
  Future<List<String>> fetchMakes() async {
    final uri = Uri.parse('$_base/GetMakesForVehicleType/car?format=json');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('NHTSA makes fetch failed: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['Results'] as List<dynamic>;
    final makes = results
        .map((r) => (r['MakeName'] as String?)?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    makes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return makes;
  }

  /// Fetches models for a given make. Returns sorted list or throws on failure.
  Future<List<String>> fetchModels(String make) async {
    final encoded = Uri.encodeComponent(make);
    final uri = Uri.parse('$_base/getmodelsformake/$encoded?format=json');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('NHTSA models fetch failed: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['Results'] as List<dynamic>;
    final models = results
        .map((r) => (r['Model_Name'] as String?)?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    models.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return models;
  }
}
