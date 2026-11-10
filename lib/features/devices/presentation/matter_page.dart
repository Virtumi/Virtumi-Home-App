import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/matter_action_card.dart';
import 'widgets/matter_pairing_status_card.dart';
import 'widgets/matter_qr_pairing_card.dart';

/// Matter / Thread settings ("Matter Einstellungen").
class MatterPage extends ConsumerWidget {
  const MatterPage({super.key, required this.deviceId});
  final String deviceId;

  Future<void> _activatePairingMode(
    BuildContext context,
    WidgetRef ref,
    MatterConfig config,
  ) async {
    await ref
        .read(deviceRequestRepositoryProvider)
        .sendMatterPairingRequest(deviceId);

    String? error;
    if (ref.read(isDirectConnectionProvider)) {
      await Future<void>.delayed(const Duration(seconds: 2));
    } else {
      error = await ref.read(deviceRequestRepositoryProvider).pollRequestStatus(
            table: 'matter_requests',
            deviceId: deviceId,
          );
    }

    ref.invalidate(matterConfigProvider(deviceId));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Kopplungsmodus aktiviert',
        ),
      ),
    );
  }

  Future<void> _factoryReset(
    BuildContext context,
    WidgetRef ref,
    MatterConfig config,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Werkseinstellungen'),
        content: const Text(
          'Matter wirklich auf Werkseinstellungen zurücksetzen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final updated = config.copyWith(paired: false);
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveMatterConfig(deviceId, updated);
    ref.invalidate(matterConfigProvider(deviceId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter wurde zurückgesetzt')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(matterConfigProvider(deviceId));

    return AppScaffold(
      header: AppHeader(
        onRefresh: () => ref.invalidate(matterConfigProvider(deviceId)),
      ),
      body: AsyncValueView<MatterConfig>(
        value: configAsync,
        onRetry: () => ref.invalidate(matterConfigProvider(deviceId)),
        data: (config) {
          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: deviceId,
                title: 'Matter',
                imageAsset: AppConstants.matterLogoAsset,
                accent: AppColors.accentCyan,
              ),
              if (config.hasPairingData)
                MatterPairingStatusCard(paired: config.paired)
              else
                const _MatterMissingCard(),
              const SizedBox(height: AppSpacing.md),
              MatterActionCard(
                onActivatePairing: () =>
                    _activatePairingMode(context, ref, config),
                onFactoryReset: () => _factoryReset(context, ref, config),
              ),
              if (config.hasPairingData) ...[
                const SizedBox(height: AppSpacing.md),
                MatterQrPairingCard(
                  qrPayload: config.qrPayload,
                  setupCode: config.setupCode,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatterMissingCard extends StatelessWidget {
  const _MatterMissingCard();

  @override
  Widget build(BuildContext context) {
    final color = context.palette.accentAmber;
    return AppCard(
      child: Row(
        children: [
          IconBox(
            icon: Symbols.warning,
            color: color,
            size: AppSizes.iconBoxMd,
            filled: true,
            glow: true,
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Keine Matter-Daten vorhanden.',
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  'QR-Code und Setup-Code fehlen.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
