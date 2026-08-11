import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nutrition_models.dart';

enum FoodLookupFailure { notFound, timeout, malformed, network }

class OpenFoodFactsRepository {
  OpenFoodFactsRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<Food> resolveByBarcode(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on Exception {
      throw FoodLookupFailure.timeout;
    }

    if (response.statusCode != 200) {
      throw FoodLookupFailure.network;
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception {
      throw FoodLookupFailure.malformed;
    }

    if (body['status'] != 1) {
      throw FoodLookupFailure.notFound;
    }

    final product = body['product'] as Map<String, dynamic>?;
    if (product == null) {
      throw FoodLookupFailure.malformed;
    }

    final nutriments =
        product['nutriments'] as Map<String, dynamic>? ?? const {};
    final name = (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw FoodLookupFailure.malformed;
    }

    return Food(
      id: '',
      name: name,
      barcode: barcode,
      brand: product['brands'] as String?,
      servingSize: _double(nutriments['serving_quantity']) ?? 100,
      servingUnit: (nutriments['serving_quantity_unit'] as String?) ?? 'g',
      calories:
          (_double(nutriments['energy-kcal_serving']) ??
              _double(nutriments['energy-kcal_100g'])) ??
          0,
      proteinG:
          (_double(nutriments['proteins_serving']) ??
              _double(nutriments['proteins_100g'])) ??
          0,
      carbsG:
          (_double(nutriments['carbohydrates_serving']) ??
              _double(nutriments['carbohydrates_100g'])) ??
          0,
      fatG:
          (_double(nutriments['fat_serving']) ??
              _double(nutriments['fat_100g'])) ??
          0,
      source: 'offer',
    );
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
