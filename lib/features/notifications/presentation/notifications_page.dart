import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'notification_formatting.dart';

/// Inbox behind the bell icon on the Home screen.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = unreadNotificationCount(notifications);

    return AppScaffold(
      header: AppHeader(onRefresh: () => ref.invalidate(notificationsProvider)),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: 'Benachrichtigungen',
            icon: Symbols.notifications,
            subtitle: unread == 0
                ? 'Alles gelesen'
                : (unread == 1
                      ? '1 ungelesene Nachricht'
                      : '$unread ungelesene Nachrichten'),
          ),
          AsyncValueView<List<AppNotification>>(
            value: notifications,
            onRetry: () => ref.invalidate(notificationsProvider),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Symbols.notifications_off,
                  message: 'Keine Benachrichtigungen.',
                );
              }
              return Column(
                children: [
                  for (final item in items) ...[
                    _NotificationCard(
                      notification: item,
                      onTap: () => _open(context, ref, item),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      try {
        await ref.read(deviceAccessRepositoryProvider).markRead([
          notification.id,
        ]);
      } catch (_) {
        // Opening the request must not fail because of the read flag.
      }
      ref.invalidate(notificationsProvider);
    }
    if (notification.type == AppNotificationType.deviceAccessApproved) {
      // The newly shared device must show up in houses, rooms and shares.
      invalidateLocationHierarchy(ref);
      ref.invalidate(sharedWithMeProvider);
    }
    final requestId = notification.requestId;
    if (requestId != null && context.mounted) {
      context.push(Paths.accessRequest(requestId));
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = notificationVisual(context, notification.type);
    final muted = context.colors.onSurfaceVariant;
    final unread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: visual.icon, color: visual.color, filled: true),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(notification.message, style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDateTime(notification.createdAt),
                        style: context.text.labelSmall?.copyWith(color: muted),
                      ),
                    ),
                    if (notification.needsAnswer)
                      Text(
                        'Antwort ausstehend',
                        style: context.text.labelSmall?.copyWith(
                          color: context.palette.accentOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (notification.type ==
                            AppNotificationType.deviceAccessRequest &&
                        notification.requestStatus != null)
                      Text(
                        notification.requestStatus!.label,
                        style: context.text.labelSmall?.copyWith(color: muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
