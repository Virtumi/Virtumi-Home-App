import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../../../application/new_device_wizard_controller.dart';
import '../../../application/new_device_wizard_state.dart';

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
                      info.isSelf
                          ? 'Gerät ist bereits in deinem Konto'
                          : 'Gerät ist bereits verknüpft',
                      style: context.text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                info.isSelf
                    ? '„${info.deviceName}“ gehört schon zu deinem Konto und '
                          'kann nicht erneut hinzugefügt werden.'
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
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: state.isBusy ? null : controller.goBack,
          icon: const Icon(Symbols.arrow_back),
          label: const Text('Zurück zur Geräteliste'),
        ),
      ],
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
