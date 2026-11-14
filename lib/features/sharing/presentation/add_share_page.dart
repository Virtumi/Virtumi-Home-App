import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';

/// Two-step flow: 1) find a user, 2) pick what to share (houses, floors,
/// rooms and/or devices).
///
/// When [initialUser] is given the search step is skipped (used for adding
/// further shares to a user that already has access).
class AddSharePage extends ConsumerStatefulWidget {
  const AddSharePage({super.key, this.initialUser});

  final UserSearchResult? initialUser;

  @override
  ConsumerState<AddSharePage> createState() => _AddSharePageState();
}

class _AddSharePageState extends ConsumerState<AddSharePage> {
  static const _minQueryLength = 1;
  static const _debounce = Duration(milliseconds: 250);

  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  Future<List<UserSearchResult>>? _searchFuture;

  UserSearchResult? _user;
  final _selected = <ShareScope>{};
  final _expanded = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
      setState(() => _searchFuture = null);
      return;
    }
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() {
        _searchFuture = ref.read(sharingRepositoryProvider).searchUsers(query);
      });
    });
  }

  void _goBack() {
    if (_user != null && widget.initialUser == null) {
      setState(() {
        _user = null;
        _selected.clear();
        _expanded.clear();
      });
      return;
    }
    context.pop();
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null || _selected.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(sharingRepositoryProvider).addShares(
            user.userId,
            _selected,
          );
      ref.invalidate(mySharesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Freigabe für ${user.displayName} gespeichert')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Freigabe fehlgeschlagen: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return AppScaffold(
      header: AppHeader(onBack: _goBack),
      body: AppScrollView(
        children: user == null ? _buildSearchStep() : _buildScopeStep(user),
      ),
    );
  }

  // ---------------------------------------------------------------- step 1

  List<Widget> _buildSearchStep() {
    return [
      const SectionHeaderCard(
        title: 'Benutzer hinzufügen',
        icon: Symbols.person_search,
        subtitle: 'Suche nach Vorname, Nachname oder E-Mail-Adresse.',
      ),
      TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        onChanged: _onQueryChanged,
        decoration: InputDecoration(
          hintText: 'Name oder E-Mail',
          prefixIcon: const Icon(Symbols.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Symbols.close),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                ),
        ),
      ),
      _buildSearchResults(),
    ];
  }

  Widget _buildSearchResults() {
    final future = _searchFuture;
    if (future == null) {
      return const EmptyState(
        icon: Symbols.person_search,
        message: 'Tippe einen Namen oder eine E-Mail-Adresse, '
            'um Benutzer zu suchen.',
      );
    }

    return FutureBuilder<List<UserSearchResult>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.sectionMargin),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Symbols.error,
            message: 'Suche fehlgeschlagen: ${snapshot.error}',
          );
        }
        final users = snapshot.data ?? const <UserSearchResult>[];
        if (users.isEmpty) {
          return const EmptyState(
            icon: Symbols.person_off,
            message: 'Kein Benutzer gefunden.',
          );
        }

        return GroupedListCard(
          children: [
            for (final user in users)
              _UserRow(
                user: user,
                onTap: () => setState(() => _user = user),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- step 2

  List<Widget> _buildScopeStep(UserSearchResult user) {
    final targetsAsync = ref.watch(shareableTargetsProvider);
    final sharesAsync = ref.watch(mySharesProvider);

    final existing = <ShareScope>{
      for (final share in sharesAsync.value ?? const <DeviceShare>[])
        if (share.user.userId == user.userId)
          ShareScope(share.scopeType, share.scopeId),
    };

    return [
      SectionHeaderCard(
        title: user.displayName,
        icon: Symbols.person,
        subtitle: user.fullName.isNotEmpty ? user.email : null,
        detail: 'Wähle, was freigegeben werden soll.',
      ),
      AsyncValueView<List<ShareTarget>>(
        value: targetsAsync,
        onRetry: () => ref.invalidate(shareableTargetsProvider),
        data: (targets) {
          if (targets.isEmpty) {
            return const EmptyState(
              icon: Symbols.home_work,
              message: 'Du hast noch keine Häuser mit Geräten, '
                  'die du freigeben kannst.',
            );
          }
          return AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final house in targets)
                  ..._buildNode(house, 0, existing, covered: false),
              ],
            ),
          );
        },
      ),
      FilledButton.icon(
        onPressed: _selected.isEmpty || _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Symbols.person_add),
        label: Text(
          _selected.isEmpty
              ? 'Freigeben'
              : 'Freigeben (${_selected.length})',
        ),
      ),
    ];
  }

  List<Widget> _buildNode(
    ShareTarget node,
    int depth,
    Set<ShareScope> existing, {
    required bool covered,
  }) {
    final scope = node.scope;
    final alreadyShared = existing.contains(scope);
    final isSelected = _selected.contains(scope);
    final inherited = covered || alreadyShared;
    final checked = inherited || isSelected;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expanded.contains(node.id);

    final rows = <Widget>[
      _ScopeRow(
        depth: depth,
        node: node,
        checked: checked,
        note: alreadyShared
            ? 'Bereits freigegeben'
            : covered
                ? 'Über übergeordnete Freigabe'
                : null,
        expandable: hasChildren,
        expanded: isExpanded,
        onToggleExpand: () => setState(() {
          if (!_expanded.add(node.id)) _expanded.remove(node.id);
        }),
        onChanged: covered || alreadyShared
            ? null
            : (value) => setState(() {
                  if (value == true) {
                    _selected.add(scope);
                  } else {
                    _selected.remove(scope);
                  }
                }),
      ),
    ];

    if (hasChildren && isExpanded) {
      for (final child in node.children) {
        rows.addAll(
          _buildNode(
            child,
            depth + 1,
            existing,
            covered: inherited || isSelected,
          ),
        );
      }
    }
    return rows;
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});

  final UserSearchResult user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      semanticLabel: user.displayName,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            UserAvatar(
              initials: user.initials,
              imageUrl: user.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: context.text.bodyLarge),
                  if (user.fullName.isNotEmpty && user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.depth,
    required this.node,
    required this.checked,
    required this.expandable,
    required this.expanded,
    required this.onToggleExpand,
    required this.onChanged,
    this.note,
  });

  final int depth;
  final ShareTarget node;
  final bool checked;
  final bool expandable;
  final bool expanded;
  final String? note;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm + depth * AppSpacing.lg,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: expandable
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      expanded ? Symbols.expand_more : Symbols.chevron_right,
                      color: muted,
                    ),
                    onPressed: onToggleExpand,
                    tooltip: expanded ? 'Zuklappen' : 'Aufklappen',
                  )
                : null,
          ),
          Icon(node.type.icon, size: 22, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(!checked),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name.isEmpty ? node.type.label : node.name,
                      style: context.text.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      note ?? node.type.label,
                      style: context.text.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Checkbox(value: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
