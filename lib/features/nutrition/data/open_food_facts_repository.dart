import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nutrition_models.dart';

enum FoodLookupFailure { invalidBarcode, notFound, timeout, malformed, network }

typedef FoodLookupFallback =
    Future<Map<String, dynamic>> Function(String barcode);

class OpenFoodFactsRepository {
  OpenFoodFactsRepository({
    http.Client? client,
    this.fallbackLookup,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final FoodLookupFallback? fallbackLookup;
  final Duration timeout;

  static const _userAgent =
      'EnfermiCambio/1.1 (https://github.com/freddyf-beep/enfermicambio)';

  /// Accepts EAN/UPC formats supported by Open Food Facts and removes the
  /// separators produced by some barcode scanners.
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

    Map<String, dynamic> body;
    try {
      body = await _fetchDirect(normalized);
    } on FoodLookupFailure catch (failure) {
      final fallback = fallbackLookup;
      if (fallback == null ||
          failure == FoodLookupFailure.invalidBarcode ||
          failure == FoodLookupFailure.notFound) {
        rethrow;
      }
      try {
        body = await fallback(normalized).timeout(timeout);
      } on TimeoutException {
        throw FoodLookupFailure.timeout;
      } on FoodLookupFailure {
        rethrow;
      } on Exception {
        throw failure;
      }
    }
    return _foodFromBody(body, normalized);
  }

  Future<Map<String, dynamic>> _fetchDirect(String normalized) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v3/product/$normalized',
      {
        'fields':
            'product_name,brands,serving_quantity,serving_quantity_unit,serving_size,nutriments,nutrition',
      },
    );

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw FoodLookupFailure.timeout;
    } on Exception {
      throw FoodLookupFailure.network;
    }

    if (response.statusCode == 404) {
      throw FoodLookupFailure.notFound;
    }
    if (response.statusCode != 200) {
      throw FoodLookupFailure.network;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return Map<String, dynamic>.from(decoded);
    } on Exception {
      throw FoodLookupFailure.malformed;
    }
  }

  Food _foodFromBody(Map<String, dynamic> body, String normalized) {
    final status = body['status'];
    if (status == 0 || status == 'failure' || status == 'not_found') {
      throw FoodLookupFailure.notFound;
    }

    final rawProduct = body['product'];
    if (rawProduct == null) {
      throw FoodLookupFailure.notFound;
    }
    if (rawProduct is! Map) {
      throw FoodLookupFailure.malformed;
    }
    final product = Map<String, dynamic>.from(rawProduct);
    final rawNutriments = product['nutriments'];
    final nutriments = rawNutriments is Map
        ? Map<String, dynamic>.from(rawNutriments)
        : const <String, dynamic>{};
    final rawNutrition = product['nutrition'];
    final nutrition = rawNutrition is Map
        ? Map<String, dynamic>.from(rawNutrition)
        : const <String, dynamic>{};

    final name = _string(product['product_name']);
    if (name == null) {
      throw FoodLookupFailure.malformed;
    }

    final servingSize = _servingSize(product, nutriments);
    return Food(
      id: '',
      name: name,
      barcode: normalized,
      brand: _string(product['brands']),
      servingSize: servingSize,
      servingUnit: _servingUnit(product),
      calories: _nutrientForServing(
        product: product,
        nutriments: nutriments,
        nutrition: nutrition,
        nutrient: 'energy-kcal',
        servingSize: servingSize,
      ),
      proteinG: _nutrientForServing(
        product: product,
        nutriments: nutriments,
        nutrition: nutrition,
        nutrient: 'proteins',
        servingSize: servingSize,
      ),
      carbsG: _nutrientForServing(
        product: product,
        nutriments: nutriments,
        nutrition: nutrition,
        nutrient: 'carbohydrates',
        servingSize: servingSize,
      ),
      fatG: _nutrientForServing(
        product: product,
        nutriments: nutriments,
        nutrition: nutrition,
        nutrient: 'fat',
        servingSize: servingSize,
      ),
      source: 'open_food_facts',
    );
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.').trim());
    }
    if (value is Map) {
      return _double(value['value_computed']) ??
          _double(value['value']) ??
          _double(value['amount']);
    }
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

  String _servingUnit(Map<String, dynamic> product) {
    final explicit = _string(product['serving_quantity_unit']);
    if (explicit != null) return explicit;
    final servingText = _string(product['serving_size']);
    if (servingText != null) {
      final unit = RegExp(r'([a-zA-Zµ]+)\s*$').firstMatch(servingText);
      if (unit != null) return unit.group(1)!;
    }
    return 'g';
  }

  double _nutrientForServing({
    required Map<String, dynamic> product,
    required Map<String, dynamic> nutriments,
    required Map<String, dynamic> nutrition,
    required String nutrient,
    required double servingSize,
  }) {
    final perServing = _firstDouble(nutriments, <String>[
      '${nutrient}_serving',
      '${nutrient}_serve',
      '${nutrient}_per_serving',
    ]);
    if (perServing != null) return perServing;

    final per100 = _firstDouble(nutriments, <String>[
      '${nutrient}_100g',
      '${nutrient}_100ml',
      '${nutrient}_per_100g',
      nutrient,
    ]);
    if (per100 != null) return per100 * servingSize / 100;

    // v3 can expose the same values inside nutrition.aggregated_set. Keep
    // this fallback tolerant because the exact set can vary by product.
    final nested = _nestedNutrient(nutrition, nutrient);
    final nestedServing = _firstDoubleFromMap(nested, const [
      'per_serving',
      'serving',
      'value_serving',
    ]);
    if (nestedServing != null) return nestedServing;
    final nested100 = _firstDoubleFromMap(nested, const [
      'per_100g',
      'per_100ml',
      'value_100g',
      'value',
    ]);
    if (nested100 != null) return nested100 * servingSize / 100;

    // Some localized v3 responses put a nutrient object directly on product.
    return _double(product[nutrient]) ?? 0;
  }

  double? _firstDouble(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = _double(values[key]);
      if (value != null) return value;
    }
    return null;
  }

  Map<String, dynamic> _nestedNutrient(
    Map<String, dynamic> nutrition,
    String nutrient,
  ) {
    final aggregated = nutrition['aggregated_set'];
    if (aggregated is Map) {
      final nutrients = aggregated['nutrients'];
      if (nutrients is Map) {
        final value = nutrients[nutrient];
        if (value is Map) return Map<String, dynamic>.from(value);
      }
    }
    final value = nutrition[nutrient];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  double? _firstDoubleFromMap(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = _double(values[key]);
      if (value != null) return value;
    }
    return null;
  }

  double? _numberFromText(dynamic value) {
    if (value is! String) return null;
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    return match == null
        ? null
        : double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }
}
