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

/// Overview of shares: who may access my devices, and what was shared with me.
class SharingPage extends ConsumerWidget {
  const SharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myShares = ref.watch(mySharesProvider);
    final sharedWithMe = ref.watch(sharedWithMeProvider);
    final p = context.palette;

    return AppScaffold(
      header: const AppHeader(),
      body: AppScrollView(
        children: [
          const SectionHeaderCard(
            title: 'Freigaben',
            icon: Symbols.group_add,
            subtitle: 'Gib Häuser, Etagen, Räume oder Geräte für andere '
                'Benutzer frei.',
          ),
          ActionBannerCard(
            icon: Symbols.person_add,
            title: 'Benutzer hinzufügen',
            subtitle: 'Per Name oder E-Mail suchen',
            accent: p.accentTeal,
            trailingIcon: Symbols.add,
            trailingFilledButton: true,
            onTap: () => context.push(Paths.addShare),
          ),
          const AppSectionLabel('Von mir freigegeben'),
          AsyncValueView<List<DeviceShare>>(
            value: myShares,
            onRetry: () => ref.invalidate(mySharesProvider),
            data: (shares) {
              if (shares.isEmpty) {
                return const EmptyState(
                  icon: Symbols.group,
                  message: 'Du hast noch nichts freigegeben.',
                );
              }
              final groups = _groupByUser(shares);
              return Column(
                children: [
                  for (final group in groups) ...[
                    _ShareGroupCard(
                      user: group.user,
                      shares: group.shares,
                      removeAllLabel: 'Alle Freigaben entfernen',
                      onAdd: () => context.push(
                        Paths.addShare,
                        extra: group.user,
                      ),
                      onRemoveAll: () => _confirmRemove(
                        context,
                        ref,
                        title: 'Zugriff entziehen?',
                        message:
                            '${group.user.displayName} verliert den Zugriff '
                            'auf alle freigegebenen Geräte.',
                        confirmLabel: 'Entfernen',
                        shares: group.shares,
                      ),
                      onRemove: (share) => _confirmRemove(
                        context,
                        ref,
                        title: 'Freigabe entfernen?',
                        message:
                            '${group.user.displayName} verliert den Zugriff '
                            'auf "${share.scopeName}".',
                        confirmLabel: 'Entfernen',
                        shares: [share],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                ],
              );
            },
          ),
          sharedWithMe.maybeWhen(
            data: (shares) {
              if (shares.isEmpty) return const SizedBox.shrink();
              final groups = _groupByUser(shares);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionLabel('Mit mir geteilt'),
                  for (final group in groups) ...[
                    _ShareGroupCard(
                      user: group.user,
                      shares: group.shares,
                      removeAllLabel: 'Alle Freigaben verlassen',
                      onRemoveAll: () => _confirmRemove(
                        context,
                        ref,
                        title: 'Freigaben verlassen?',
                        message:
                            'Du verlierst den Zugriff auf alle Geräte von '
                            '${group.user.displayName}.',
                        confirmLabel: 'Verlassen',
                        shares: group.shares,
                        refreshHierarchy: true,
                      ),
                      onRemove: (share) => _confirmRemove(
                        context,
                        ref,
                        title: 'Freigabe verlassen?',
                        message: 'Du verlierst den Zugriff auf '
                            '"${share.scopeName}".',
                        confirmLabel: 'Verlassen',
                        shares: [share],
                        refreshHierarchy: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static List<_ShareGroup> _groupByUser(List<DeviceShare> shares) {
    final byUser = <String, _ShareGroup>{};
    for (final share in shares) {
      byUser
          .putIfAbsent(
            share.user.userId,
            () => _ShareGroup(share.user, []),
          )
          .shares
          .add(share);
    }
    return byUser.values.toList();
  }

  static Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required String confirmLabel,
    required List<DeviceShare> shares,
    bool refreshHierarchy = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(sharingRepositoryProvider)
          .removeShares(shares.map((share) => share.id));
      ref.invalidate(mySharesProvider);
      ref.invalidate(sharedWithMeProvider);
      if (refreshHierarchy) invalidateLocationHierarchy(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entfernen fehlgeschlagen: $error')),
      );
    }
  }
}

class _ShareGroup {
  _ShareGroup(this.user, this.shares);

  final UserSearchResult user;
  final List<DeviceShare> shares;
}

class _ShareGroupCard extends StatelessWidget {
  const _ShareGroupCard({
    required this.user,
    required this.shares,
    required this.removeAllLabel,
    required this.onRemoveAll,
    required this.onRemove,
    this.onAdd,
  });

  final UserSearchResult user;
  final List<DeviceShare> shares;
  final String removeAllLabel;
  final VoidCallback onRemoveAll;
  final ValueChanged<DeviceShare> onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(initials: user.initials, size: 44),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: context.text.titleMedium),
                    if (user.fullName.isNotEmpty && user.email.isNotEmpty)
                      Text(
                        user.email,
                        style: context.text.bodySmall?.copyWith(color: muted),
                      ),
                  ],
                ),
              ),
              if (onAdd != null)
                IconButton(
                  tooltip: 'Weitere Freigabe hinzufügen',
                  icon: const Icon(Symbols.add_circle),
                  onPressed: onAdd,
                ),
              IconButton(
                tooltip: removeAllLabel,
                icon: Icon(Symbols.person_remove, color: context.colors.error),
                onPressed: onRemoveAll,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final share in shares)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    share.scopeType.icon,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          share.scopeName.isEmpty
                              ? share.scopeType.label
                              : share.scopeName,
                          style: context.text.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            share.scopeType.label,
                            if (share.scopePath != null) share.scopePath!,
                          ].join(' · '),
                          style: context.text.labelSmall
                              ?.copyWith(color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Entfernen',
                    icon: Icon(Symbols.close, color: muted),
                    onPressed: () => onRemove(share),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
