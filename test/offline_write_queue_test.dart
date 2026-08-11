import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enfermicambio/features/app/data/offline_write_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue persists a pending write', () async {
    final queue = await OfflineWriteQueue.open();
    await queue.enqueue(
      operation: 'create_text_post',
      payload: {'caption': 'offline hello'},
    );

    final pending = await queue.pending();
    expect(pending.length, 1);
    expect(pending.single.operation, 'create_text_post');
    expect(pending.single.payload['caption'], 'offline hello');
  });

  test('flush removes successful writes and keeps failed ones', () async {
    final queue = await OfflineWriteQueue.open();
    await queue.enqueue(operation: 'op_ok', payload: {'n': 1});
    await queue.enqueue(operation: 'op_fail', payload: {'n': 2});

    final remaining = await queue.flush((write) async {
      if (write.operation == 'op_fail') {
        throw StateError('offline');
      }
    });

    expect(remaining.length, 1);
    expect(remaining.single.operation, 'op_fail');

    final pending = await queue.pending();
    expect(pending.length, 1);
    expect(pending.single.operation, 'op_fail');
  });

  test('pending survives reopen (persistence)', () async {
    final first = await OfflineWriteQueue.open();
    await first.enqueue(operation: 'add_reaction', payload: {'emoji': 'x'});

    final second = await OfflineWriteQueue.open();
    final pending = await second.pending();
    expect(pending.length, 1);
    expect(pending.single.operation, 'add_reaction');
  });
}
