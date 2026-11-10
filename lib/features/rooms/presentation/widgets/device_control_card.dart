import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/application/direct_device_link.dart';
import '../../../../shared/models/models.dart';
import 'device_card_text_styles.dart';
import 'device_online_badge.dart';

/// Control card for a single device inside the room overview.
///
/// Shows a summary (icon, name, type), connectivity status, a power quick-action
/// toggle, and two affordances: settings (gear) and details (arrow).
class DeviceControlCard extends ConsumerWidget {
  const DeviceControlCard({
    super.key,
    required this.device,
    required this.onOpenDetails,
    required this.onOpenSettings,
    required this.onTogglePower,
  });

  final Device device;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSettings;
  final ValueChanged<bool> onTogglePower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = deviceIsOnline(ref, device);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: device.type.icon,
                color: context.colors.primary,
                size: AppSizes.iconBoxMd,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      style: DeviceCardTextStyles.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.type.label,
                      style: DeviceCardTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
              DeviceOnlineBadge(device: device),
              if (online) ...[
                const SizedBox(width: AppSpacing.sm),
                NeumorphicIconButton(
                  icon: Symbols.settings,
                  iconColor: context.colors.onSurface,
                  size: 40,
                  iconSize: 20,
                  tooltip: 'Geräteeinstellungen',
                  onPressed: onOpenSettings,
                ),
                const SizedBox(width: AppSpacing.sm),
                NeumorphicIconButton(
                  icon: Symbols.arrow_forward,
                  size: 40,
                  iconSize: 20,
                  tooltip: 'Gerätedetails',
                  onPressed: onOpenDetails,
                ),
              ],
            ],
          ),
          if (online) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Spacer(),
                Text(
                  device.statusLabel,
                  style: DeviceCardTextStyles.caption(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppToggle(
                  value: device.isOn,
                  onChanged: onTogglePower,
                  semanticLabel: '${device.name} Ein/Aus',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
