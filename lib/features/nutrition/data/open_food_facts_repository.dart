import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nutrition_models.dart';

enum FoodLookupFailure { invalidBarcode, notFound, timeout, malformed, network }

class OpenFoodFactsRepository {
  OpenFoodFactsRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Open Food Facts accepts product codes, but rejecting obvious invalid
  /// values locally makes the scanner error useful and avoids a needless call.
  static String? normalizeBarcode(String raw) {
    final value = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  Future<Food> resolveByBarcode(String barcode) async {
    final normalized = normalizeBarcode(barcode);
    if (normalized == null) throw FoodLookupFailure.invalidBarcode;
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$normalized.json',
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
      barcode: normalized,
      brand: product['brands'] as String?,
      servingSize: _servingSize(product, nutriments),
      servingUnit: (product['serving_quantity_unit'] as String?) ?? 'g',
      calories: _nutrientForServing(
        nutriments['energy-kcal_serving'],
        nutriments['energy-kcal_100g'],
        _servingSize(product, nutriments),
      ),
      proteinG: _nutrientForServing(
        nutriments['proteins_serving'],
        nutriments['proteins_100g'],
        _servingSize(product, nutriments),
      ),
      carbsG: _nutrientForServing(
        nutriments['carbohydrates_serving'],
        nutriments['carbohydrates_100g'],
        _servingSize(product, nutriments),
      ),
      fatG: _nutrientForServing(
        nutriments['fat_serving'],
        nutriments['fat_100g'],
        _servingSize(product, nutriments),
      ),
      source: 'open_food_facts',
    );
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _servingSize(
    Map<String, dynamic> product,
    Map<String, dynamic> nutriments,
  ) {
    return _double(product['serving_quantity']) ??
        _double(nutriments['serving_quantity']) ??
        _numberFromText(product['serving_size']) ??
        100;
  }

  double _nutrientForServing(
    dynamic perServing,
    dynamic per100g,
    double servingSize,
  ) => _double(perServing) ?? ((_double(per100g) ?? 0) * servingSize / 100);

  double? _numberFromText(dynamic value) {
    if (value is! String) return null;
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    return match == null
        ? null
        : double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }
}
