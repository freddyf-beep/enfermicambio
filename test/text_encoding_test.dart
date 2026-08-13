import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/shared/text/text_encoding.dart';

void main() {
  test('repairs Spanish accents and emoji from old rows', () {
    const broken =
        '\u00F0\u0178\u008F\u2020 Samir te pas\u00C3\u00B3 por 1.245 pasos.';

    expect(repairMojibake(broken), '🏆 Samir te pasó por 1.245 pasos.');
  });

  test('leaves correctly encoded text unchanged', () {
    expect(
      repairMojibake('La ronda está por cerrar 🌙'),
      'La ronda está por cerrar 🌙',
    );
  });
}
