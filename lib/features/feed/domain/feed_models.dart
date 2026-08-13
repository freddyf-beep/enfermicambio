enum PostType {
  text,
  photo,
  meal,
  workout,
  route,
  achievement,
  steps,
  rankingChange,
  roundResult,
  mission,
  season,
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.type,
    required this.createdAt,
    required this.isSystem,
    this.caption,
    this.workoutId,
    this.authorAvatarUrl,
    this.mediaUrls = const [],
    this.reactionCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final PostType type;
  final DateTime createdAt;
  final bool isSystem;
  final String? caption;
  final String? workoutId;
  final List<String> mediaUrls;
  final int reactionCount;
  final int commentCount;
}

class FeedPage {
  const FeedPage({required this.posts, required this.nextCursor});

  final List<FeedPost> posts;
  final String? nextCursor;
}

abstract interface class FeedRepository {
  Future<FeedPage> loadLatest({required int limit});

  Future<FeedPage> loadAfter({required String cursor, required int limit});
}
