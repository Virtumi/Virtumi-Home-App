import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'notification_formatting.dart';

/// Detail view of one device access request.
///
/// The owner sees who asks for which device and can approve (grants access to
/// exactly this device) or decline. The requester sees the current status.
class DeviceAccessRequestPage extends ConsumerStatefulWidget {
  const DeviceAccessRequestPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<DeviceAccessRequestPage> createState() =>
      _DeviceAccessRequestPageState();
}

class _DeviceAccessRequestPageState
    extends ConsumerState<DeviceAccessRequestPage> {
  var _busy = false;

  Future<void> _respond(DeviceAccessRequest request, bool approve) async {
    if (approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Freigabe genehmigen?'),
          content: Text(
            '${request.requester.displayName} bekommt Zugriff auf '
            '„${request.deviceName}“. Andere Geräte bleiben unberührt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Genehmigen'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(deviceAccessRepositoryProvider)
          .respond(request.id, approve: approve);
      ref.invalidate(deviceAccessRequestProvider(request.id));
      ref.invalidate(notificationsProvider);
      if (approve) ref.invalidate(mySharesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Freigabe für „${request.deviceName}“ erteilt.'
                : 'Anfrage abgelehnt.',
          ),
        ),
      );
    } on DeviceAccessException catch (e) {
      ref.invalidate(deviceAccessRequestProvider(request.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(
      deviceAccessRequestProvider(widget.requestId),
    );
    final currentUserId = ref
        .watch(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;

    return AppScaffold(
      header: const AppHeader(),
      body: AppScrollView(
        children: [
          AsyncValueView<DeviceAccessRequest?>(
            value: requestAsync,
            onRetry: () =>
                ref.invalidate(deviceAccessRequestProvider(widget.requestId)),
            data: (request) {
              if (request == null) {
                return const EmptyState(
                  icon: Symbols.search_off,
                  message: 'Anfrage nicht gefunden.',
                );
              }
              final isOwner = request.ownerId == currentUserId;
              return _RequestContent(
                request: request,
                isOwner: isOwner,
                busy: _busy,
                onApprove: () => _respond(request, true),
                onDecline: () => _respond(request, false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestContent extends StatelessWidget {
  const _RequestContent({
    required this.request,
    required this.isOwner,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final DeviceAccessRequest request;
  final bool isOwner;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = context.colors.onSurfaceVariant;
    final requester = request.requester;

    final (statusColor, statusIcon) = switch (request.status) {
      DeviceAccessStatus.pending => (
        palette.accentOrange,
        Symbols.hourglass_top,
      ),
      DeviceAccessStatus.approved => (
        palette.accentGreen,
        Symbols.check_circle,
      ),
      DeviceAccessStatus.declined => (palette.accentRed, Symbols.cancel),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeaderCard(
          title: isOwner ? 'Freigabeanfrage' : 'Deine Anfrage',
          subtitle: request.deviceName,
          detail: request.devicePath,
          icon: Symbols.key,
          accent: palette.accentOrange,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        if (isOwner) ...[
          const AppSectionLabel('Anfrage von'),
          AppCard(
            child: Row(
              children: [
                UserAvatar(
                  initials: requester.initials,
                  size: 48,
                  borderRadius: AppRadius.full,
                ),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameLastFirst(requester),
                        style: context.text.titleMedium,
                      ),
                      if (requester.email.isNotEmpty)
                        Text(
                          requester.email,
                          style: context.text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBox(icon: statusIcon, color: statusColor, filled: true),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Text(
                      request.status.label,
                      style: context.text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _statusText(),
                style: context.text.bodyMedium?.copyWith(color: muted),
              ),
              if (request.createdAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Gesendet: ${formatDateTime(request.createdAt!)}',
                  style: context.text.labelSmall?.copyWith(color: muted),
                ),
              ],
              if (request.respondedAt != null)
                Text(
                  'Beantwortet: ${formatDateTime(request.respondedAt!)}',
                  style: context.text.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
        if (isOwner && request.isPending) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: busy ? null : onApprove,
            icon: const Icon(Symbols.check_circle, size: 20),
            label: const Text('Genehmigen'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: busy ? null : onDecline,
            icon: Icon(Symbols.close, color: context.colors.error),
            label: const Text('Ablehnen'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }

  String _statusText() {
    final name = request.requester.displayName;
    return switch ((isOwner, request.status)) {
      (true, DeviceAccessStatus.pending) =>
        '$name möchte Zugriff auf dieses Gerät. Mit „Genehmigen“ gibst du '
            'nur dieses eine Gerät frei.',
      (true, DeviceAccessStatus.approved) =>
        'Du hast $name Zugriff auf dieses Gerät gegeben. Du kannst die '
            'Freigabe jederzeit unter Einstellungen > Freigaben entfernen.',
      (true, DeviceAccessStatus.declined) => 'Du hast diese Anfrage abgelehnt.',
      (false, DeviceAccessStatus.pending) =>
        'Der Besitzer hat noch nicht entschieden.',
      (false, DeviceAccessStatus.approved) =>
        'Der Besitzer hat dir Zugriff auf dieses Gerät gegeben.',
      (false, DeviceAccessStatus.declined) =>
        'Der Besitzer hat die Anfrage abgelehnt.',
    };
  }

  /// "Nachname, Vorname" if available, otherwise the e-mail address.
  String _nameLastFirst(UserSearchResult user) {
    final last = user.lastName.trim();
    final first = user.firstName.trim();
    if (last.isNotEmpty && first.isNotEmpty) return '$last, $first';
    if (last.isNotEmpty || first.isNotEmpty) return '$last$first';
    return user.email;
  }
}
