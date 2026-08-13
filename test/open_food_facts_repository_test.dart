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
    expect(food.source, 'open_food_facts');
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
      () =>
          OpenFoodFactsRepository(client: client).resolveByBarcode('99999999'),
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
      ).resolveByBarcode('12345678'),
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
      () =>
          OpenFoodFactsRepository(client: client).resolveByBarcode('12345678'),
      throwsA(FoodLookupFailure.malformed),
    );
  });

  test('normalizes valid EAN/UPC codes and rejects invalid values', () {
    expect(
      OpenFoodFactsRepository.normalizeBarcode(' 1234-5678-9012 '),
      '123456789012',
    );
    expect(OpenFoodFactsRepository.normalizeBarcode('12345ABC'), isNull);
    expect(OpenFoodFactsRepository.normalizeBarcode('1234567'), isNull);
  });

  test('scales 100 gram nutrition to the configured serving', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Galletas',
            'serving_quantity': 30,
            'serving_quantity_unit': 'g',
            'nutriments': {'energy-kcal_100g': 500, 'proteins_100g': 10},
          },
        }),
        200,
      ),
    );
    final food = await OpenFoodFactsRepository(
      client: client,
    ).resolveByBarcode('12345678');
    expect(food.calories, 150);
    expect(food.proteinG, 3);
  });
}
