import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/ui/app_theme.dart';
import '../domain/feed_models.dart';

class FeedList extends StatelessWidget {
  const FeedList({
    super.key,
    required this.posts,
    this.hasMore = false,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.onReact,
    this.onComment,
    this.errorMessage,
    this.onRetry,
  });

  final List<FeedPost> posts;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final void Function(FeedPost post)? onReact;
  final void Function(FeedPost post)? onComment;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.streakOrange,
              ),
              const SizedBox(height: 10),
              const Text(
                'El feed no se pudo cargar por ahora.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (posts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 48,
                color: AppColors.primaryLight,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay publicaciones aún',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Los eventos automáticos, logros, comidas y publicaciones de los 4 amigos aparecerán aquí.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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
                      child: const Text('Cargar publicaciones anteriores'),
                    ),
            ),
          );
        }
        return _PostCard(
          post: posts[index],
          onReact: onReact,
          onComment: onComment,
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, this.onReact, this.onComment});

  final FeedPost post;
  final void Function(FeedPost post)? onReact;
  final void Function(FeedPost post)? onComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = _typeColor(post.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLight.withValues(
                    alpha: 0.2,
                  ),
                  child: Text(
                    post.authorName.isEmpty
                        ? '?'
                        : post.authorName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (post.isSystem) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.trophyPurple.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SISTEMA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.trophyPurple,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat.MMMd('es').add_Hm().format(post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabel(post.type),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (post.caption != null) ...[
              const SizedBox(height: 10),
              Text(
                post.caption!,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ],
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.mediaUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      post.mediaUrls[index],
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 140,
                        color: AppColors.darkSurfaceVariant,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.streakOrange,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (onReact != null) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onReact!(post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 18,
                            color: AppColors.streakOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.reactionCount > 0
                                ? '${post.reactionCount}'
                                : 'Reaccionar',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.streakOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (onComment != null) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onComment!(post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.commentCount > 0
                                ? '${post.commentCount}'
                                : 'Comentar',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(PostType type) {
    return switch (type) {
      PostType.text => 'Publicación',
      PostType.photo => 'Foto',
      PostType.meal => 'Comida 🍽️',
      PostType.workout => 'Entrenamiento 🏃',
      PostType.route => 'Ruta 📍',
      PostType.achievement => 'Logro 🏆',
      PostType.steps => 'Hito de Pasos 👣',
      PostType.rankingChange => 'Adelantamiento ⚡',
      PostType.roundResult => 'Franja Horaria 🥇',
      PostType.mission => 'Misión 🎯',
      PostType.season => 'Temporada 👑',
    };
  }

  Color _typeColor(PostType type) {
    return switch (type) {
      PostType.text => AppColors.primaryLight,
      PostType.photo => AppColors.primaryLight,
      PostType.meal => AppColors.macroCarbs,
      PostType.workout => AppColors.fitnessGreen,
      PostType.route => AppColors.fitnessGreen,
      PostType.achievement => AppColors.trophyPurple,
      PostType.steps => AppColors.primaryLight,
      PostType.rankingChange => AppColors.streakOrange,
      PostType.roundResult => AppColors.trophyPurple,
      PostType.mission => AppColors.fitnessGreen,
      PostType.season => AppColors.trophyPurple,
    };
  }
}
