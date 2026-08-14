import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/notifications/data/push_notification_service.dart';

void main() {
  test('push status distinguishes a registered device', () {
    const status = PushNotificationStatus(
      state: PushRegistrationState.registered,
      detail: 'El teléfono está listo.',
      platform: 'Android',
    );

    expect(status.isRegistered, isTrue);
    expect(status.platform, 'Android');
  });

  test('push status does not claim registration before a token exists', () {
    const status = PushNotificationStatus(
      state: PushRegistrationState.apnsUnavailable,
      detail: 'Falta el token APNs.',
    );

    expect(status.isRegistered, isFalse);
  });
}
