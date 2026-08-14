import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/notifications/data/ntfy_bridge_service.dart';

void main() {
  test('builds the private ntfy subscription URL', () {
    const subscription = NtfySubscription(
      topic: 'enfermicambio_012345678901234567',
      serverUrl: 'https://ntfy.sh',
    );

    expect(
      subscription.url.toString(),
      'https://ntfy.sh/enfermicambio_012345678901234567',
    );
  });

  test('does not duplicate a trailing slash in the server URL', () {
    const subscription = NtfySubscription(
      topic: 'enfermicambio_012345678901234567',
      serverUrl: 'https://ntfy.sh/',
    );

    expect(subscription.url.path, '/enfermicambio_012345678901234567');
  });
}
