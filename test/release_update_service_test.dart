import 'package:flutter_test/flutter_test.dart';
import 'package:enfermicambio/shared/update/release_update_service.dart';

void main() {
  test('detecta una versión mayor aunque el build sea menor', () {
    expect(
      ReleaseUpdateService.isNewer(
        currentVersion: '1.2.3',
        currentBuild: 10,
        remoteVersion: '1.3.0',
        remoteBuild: 1,
      ),
      isTrue,
    );
  });

  test('detecta un build mayor de la misma versión', () {
    expect(
      ReleaseUpdateService.isNewer(
        currentVersion: '1.2.3',
        currentBuild: 10,
        remoteVersion: '1.2.3',
        remoteBuild: 11,
      ),
      isTrue,
    );
  });

  test('no muestra actualización para la misma versión y build', () {
    expect(
      ReleaseUpdateService.isNewer(
        currentVersion: '1.2.3',
        currentBuild: 10,
        remoteVersion: '1.2.3',
        remoteBuild: 10,
      ),
      isFalse,
    );
  });
}
