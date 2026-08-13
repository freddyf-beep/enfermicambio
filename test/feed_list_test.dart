import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/feed/presentation/feed_list.dart';

void main() {
  testWidgets('el estado vacío del feed no ocupa toda la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FeedList(posts: [])),
        ),
      ),
    );

    final cardSize = tester.getSize(find.byType(Card));
    expect(cardSize.height, lessThan(260));
  });
}
