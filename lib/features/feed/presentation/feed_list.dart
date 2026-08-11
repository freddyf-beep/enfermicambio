import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/feed_models.dart';

class FeedList extends StatelessWidget {
  const FeedList({
    super.key,
    required this.posts,
    this.hasMore = false,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  final List<FeedPost> posts;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No posts yet. The shared timeline will appear here.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: isLoadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: onLoadMore,
                      child: const Text('Load older posts'),
                    ),
            ),
          );
        }
        return _PostCard(post: posts[index]);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    post.authorName.isEmpty
                        ? '?'
                        : post.authorName[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: theme.textTheme.titleSmall),
                      Text(
                        DateFormat.MMMd().add_Hm().format(post.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (post.isSystem)
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
              ],
            ),
            if (post.caption != null) ...[
              const SizedBox(height: 8),
              Text(post.caption!),
            ],
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.mediaUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post.mediaUrls[index],
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 120,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _typeLabel(post.type),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(PostType type) {
    return switch (type) {
      PostType.text => 'post',
      PostType.photo => 'photo',
      PostType.meal => 'meal',
      PostType.workout => 'workout',
      PostType.route => 'route',
      PostType.achievement => 'achievement',
      PostType.steps => 'step milestone',
      PostType.rankingChange => 'ranking change',
      PostType.roundResult => 'round result',
      PostType.mission => 'mission',
      PostType.season => 'season',
    };
  }
}
