import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../../../application/new_device_wizard_controller.dart';
import '../../../application/new_device_wizard_state.dart';
import '../../../models/existing_device_change.dart';

/// Shown when a discovered device already belongs to an account.
///
/// Explains who owns it and offers two options: ask the owner for access to
/// exactly this device (option 1) or have the owner release it (option 2,
/// information only because only the owner can do that).
class WizardDeviceClaimedStep extends StatelessWidget {
  const WizardDeviceClaimedStep({
    super.key,
    required this.state,
    required this.controller,
  });

  final NewDeviceWizardState state;
  final NewDeviceWizardController controller;

  @override
  Widget build(BuildContext context) {
    final info = state.ownerInfo;
    if (info == null) return const SizedBox.shrink();

    final palette = context.palette;
    final owner = UserSearchResult(
      userId: info.ownerUserId,
      firstName: info.firstName,
      lastName: info.lastName,
      email: info.email,
    );
    final requestSent = state.accessRequestSent || info.hasPendingRequest;

    // Own device: IP address / place of the found device vs. Supabase.
    final change = info.isSelf ? state.existingChange : null;
    final ipChanged = change?.ipChanged ?? false;
    final locationChanged = change?.locationChanged ?? false;
    final hasChanges = ipChanged || locationChanged;
    final updated = state.existingUpdated;
    final askToUpdate = hasChanges && !updated;

    final String ownTitle;
    if (updated) {
      ownTitle = 'Gerät wurde aktualisiert';
    } else if (ipChanged && locationChanged) {
      ownTitle =
          'Gerät existiert bereits, aber IP-Adresse und Ort haben sich geändert';
    } else if (ipChanged) {
      ownTitle = 'Gerät existiert bereits, aber die IP-Adresse hat sich geändert';
    } else if (locationChanged) {
      ownTitle = 'Gerät existiert bereits, aber in einem anderen Raum';
    } else {
      ownTitle = 'Gerät existiert bereits';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBox(
                    icon: Symbols.link,
                    color: palette.accentOrange,
                    size: AppSizes.iconBoxLg,
                    filled: true,
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Text(
                      info.isSelf ? ownTitle : 'Gerät ist bereits verknüpft',
                      style: context.text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                info.isSelf
                    ? (hasChanges || updated
                          ? '„${info.deviceName}“ gehört schon zu deinem Konto '
                                'und wird nicht erneut hinzugefügt.'
                          : '„${info.deviceName}“ gehört schon zu deinem Konto '
                                'und kann nicht erneut hinzugefügt werden.')
                    : 'Das Gerät „${info.deviceName}“ ist mit folgendem '
                          'Benutzer verknüpft:',
                style: context.text.bodyMedium,
              ),
              if (!info.isSelf) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    UserAvatar(
                      initials: owner.initials,
                      size: 44,
                      borderRadius: AppRadius.full,
                    ),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.ownerDisplayName,
                            style: context.text.titleSmall,
                          ),
                          if (info.email.isNotEmpty &&
                              info.email != info.ownerDisplayName)
                            Text(
                              info.email,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (change != null && askToUpdate) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _ChangeQuestionCard(
            change: change,
            isBusy: state.isBusy,
            onConfirm: controller.confirmExistingDeviceUpdate,
            onDecline: controller.goBack,
          ),
        ],
        if (updated && change != null) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _InfoCard(
            icon: Symbols.check_circle,
            color: palette.accentGreen,
            title: 'Änderungen übernommen',
            text: [
              if (ipChanged) 'Neue IP-Adresse: ${change.foundIp}',
              if (locationChanged) 'Neuer Ort: ${change.foundPlace.label}',
            ].join('\n'),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          FilledButton(
            onPressed: () => context.go(Paths.home),
            child: const Text('Zur Startseite'),
          ),
        ],
        if (info.alreadyShared && !info.isSelf) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _InfoCard(
            icon: Symbols.check_circle,
            color: palette.accentGreen,
            title: 'Du hast bereits Zugriff',
            text:
                'Dieses Gerät wurde dir bereits freigegeben. Du findest es '
                'in der Geräteübersicht.',
          ),
        ] else if (!info.isSelf) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _OptionOneCard(
            requestSent: requestSent,
            isBusy: state.isBusy,
            onRequest: controller.requestDeviceAccess,
          ),
          const SizedBox(height: AppSpacing.cardGap),
          _InfoCard(
            icon: Symbols.lock_open,
            color: palette.accentIndigo,
            title: 'Option 2: Gerät vom Besitzer befreien lassen',
            text:
                'Der Benutzer kann das Gerät selbst aus seinem Konto '
                'entfernen. Das kann nur er tun, nicht du. Danach lässt sich '
                'das Gerät in deinem Konto hinzufügen.',
          ),
        ],
        if (!askToUpdate && !updated) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : controller.goBack,
            icon: const Icon(Symbols.arrow_back),
            label: const Text('Zurück zur Geräteliste'),
          ),
        ],
      ],
    );
  }
}

/// Question shown for an own device whose IP address and/or place differ from
/// the data stored in Supabase.
class _ChangeQuestionCard extends StatelessWidget {
  const _ChangeQuestionCard({
    required this.change,
    required this.isBusy,
    required this.onConfirm,
    required this.onDecline,
  });

  final ExistingDeviceChange change;
  final bool isBusy;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ip = change.ipChanged;
    final loc = change.locationChanged;

    final String question;
    final String confirmLabel;
    if (ip && loc) {
      question = 'IP-Adresse und Ort im vorhandenen Gerät aktualisieren?';
      confirmLabel = 'Ja, aktualisieren';
    } else if (ip) {
      question = 'Soll die neue IP-Adresse im vorhandenen Gerät aktualisiert '
          'werden?';
      confirmLabel = 'Ja, aktualisieren';
    } else {
      question = 'Soll der neue Raum für dieses Gerät übernommen werden?';
      confirmLabel = 'Ja, übernehmen';
    }

    Widget line(String label, String from, String to) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelMedium),
            Text(
              'Bisher: $from',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Text('Neu: $to', style: context.text.bodyMedium),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(
                icon: loc ? Symbols.meeting_room : Symbols.lan,
                color: palette.accentOrange,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Text('Änderung erkannt', style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (ip)
            line(
              'IP-Adresse',
              change.storedIp.trim().isEmpty ? '-' : change.storedIp,
              change.foundIp,
            ),
          if (loc)
            line(
              'Ort (Home / Etage / Raum)',
              change.storedPlace.label,
              change.foundPlace.label,
            ),
          Text(question, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: isBusy ? null : onConfirm,
            icon: const Icon(Symbols.check, size: 20),
            label: Text(confirmLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: isBusy ? null : onDecline,
            child: const Text('Nein'),
          ),
        ],
      ),
    );
  }
}

class _OptionOneCard extends StatelessWidget {
  const _OptionOneCard({
    required this.requestSent,
    required this.isBusy,
    required this.onRequest,
  });

  final bool requestSent;
  final bool isBusy;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(
                icon: requestSent ? Symbols.mark_email_read : Symbols.send,
                color: requestSent
                    ? palette.accentGreen
                    : context.colors.primary,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Text(
                  'Option 1: Freigabe anfragen',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            requestSent
                ? 'Anfrage gesendet. Der Benutzer sieht sie unter '
                      'Benachrichtigungen. Sobald er entscheidet, bekommst du '
                      'eine Nachricht.'
                : 'Der Benutzer bekommt eine Anfrage und kann dir den Zugriff '
                      'nur für dieses Gerät freigeben.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (!requestSent) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: isBusy ? null : onRequest,
              icon: const Icon(Symbols.send, size: 20),
              label: const Text('Freigabe anfragen'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(icon: icon, color: color, filled: true),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(child: Text(title, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
