import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/notifications/data/bark_bridge_service.dart';

void main() {
  test('parses the Bark test URL and keeps only the device key', () {
    final config = BarkDeviceConfig.tryParse(
      'https://api.day.app/Abc_123-xyz/sample-body',
    );

    expect(config, isNotNull);
    expect(config!.deviceKey, 'Abc_123-xyz');
    expect(config.serverUrl, 'https://api.day.app');
    expect(config.endpoint.toString(), 'https://api.day.app/Abc_123-xyz');
  });

  test('accepts a copied Bark key directly', () {
    final config = BarkDeviceConfig.tryParse('Abc_123-xyz');

    expect(config, isNotNull);
    expect(config!.maskedKey, 'Abc_••••-xyz');
  });

  test('rejects an unrelated URL or an empty key', () {
    expect(BarkDeviceConfig.tryParse(''), isNull);
    expect(BarkDeviceConfig.tryParse('https://example.com/key'), isNull);
    expect(BarkDeviceConfig.tryParse('short'), isNull);
  });
}
