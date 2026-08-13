import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/feed/domain/feed_models.dart';
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

  testWidgets('una publicación real se dibuja sin un bloque gris', (
    tester,
  ) async {
    final post = FeedPost(
      id: 'post-1',
      authorId: 'user-1',
      authorName: 'Freddy',
      type: PostType.text,
      createdAt: DateTime.utc(2026, 8, 13, 11, 46),
      isSystem: false,
      caption: 'Prueba visible del feed',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(child: FeedList(posts: [post])),
        ),
      ),
    );

    expect(find.text('Freddy'), findsOneWidget);
    expect(find.text('Prueba visible del feed'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
  });
}
