import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enfermicambio/features/nutrition/data/open_food_facts_repository.dart';

void main() {
  test('resolves a product by barcode with serving nutrition', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('3017624010701.json'));
      return http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Nutella',
            'brands': 'Ferrero',
            'nutriments': {
              'energy-kcal_100g': 539,
              'proteins_100g': 6.3,
              'carbohydrates_100g': 57.5,
              'fat_100g': 30.9,
              'serving_quantity': 15,
              'serving_quantity_unit': 'g',
              'energy-kcal_serving': 81,
              'proteins_serving': 0.9,
              'carbohydrates_serving': 8.6,
              'fat_serving': 4.6,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final food = await OpenFoodFactsRepository(
      client: client,
    ).resolveByBarcode('3017624010701');

    expect(food.name, 'Nutella');
    expect(food.brand, 'Ferrero');
    expect(food.source, 'offer');
    expect(food.calories, closeTo(81, 0.01));
    expect(food.servingSize, closeTo(15, 0.01));
  });

  test('throws notFound when the product does not exist', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'status': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(
      () => OpenFoodFactsRepository(client: client).resolveByBarcode('999'),
      throwsA(FoodLookupFailure.notFound),
    );
  });

  test('throws timeout on slow responses', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response(
        jsonEncode({'status': 1}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(
      () => OpenFoodFactsRepository(
        client: client,
        timeout: const Duration(milliseconds: 50),
      ).resolveByBarcode('123'),
      throwsA(FoodLookupFailure.timeout),
    );
  });

  test('throws malformed on invalid JSON', () async {
    final client = MockClient((request) async {
      return http.Response(
        'not json',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(
      () => OpenFoodFactsRepository(client: client).resolveByBarcode('123'),
      throwsA(FoodLookupFailure.malformed),
    );
  });
}
