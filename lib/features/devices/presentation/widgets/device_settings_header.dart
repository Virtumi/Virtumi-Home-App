import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/section_header_card.dart';
import '../../../../shared/application/location_breadcrumb.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';

/// Settings title with the device name and `Home / Etage / Raum` underneath.
///
/// Each line stays empty while that part is still loading.
class DeviceSettingsHeader extends ConsumerWidget {
  const DeviceSettingsHeader({
    super.key,
    required this.deviceId,
    required this.title,
    this.icon,
    this.imageAsset,
    this.accent,
    this.filled = true,
    this.trailing,
  });

  final String deviceId;
  final String title;
  final IconData? icon;
  final String? imageAsset;
  final Color? accent;
  final bool filled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider(deviceId)).value;
    final name = device?.displayName.trim();

    return SectionHeaderCard(
      title: title,
      subtitle: name == null || name.isEmpty ? null : name,
      detail: locationBreadcrumb(
        ref,
        roomId: device?.roomId,
        includeFloor: true,
        includeRoom: true,
      ),
      icon: icon,
      imageAsset: imageAsset,
      accent: accent,
      filled: filled,
      trailing: trailing,
    );
  }
}
