import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/neumorphic_icon_button.dart';
import '../../../../shared/application/direct_device_link.dart';
import '../../../../shared/models/models.dart';
import 'device_card_text_styles.dart';

/// Online or offline icon. The word appears for a few seconds after a tap.
class DeviceOnlineBadge extends ConsumerStatefulWidget {
  const DeviceOnlineBadge({super.key, required this.device});

  final Device device;

  @override
  ConsumerState<DeviceOnlineBadge> createState() => _DeviceOnlineBadgeState();
}

class _DeviceOnlineBadgeState extends ConsumerState<DeviceOnlineBadge> {
  static const _labelDuration = Duration(seconds: 5);

  Timer? _hideLabel;
  bool _showLabel = false;

  @override
  void dispose() {
    _hideLabel?.cancel();
    super.dispose();
  }

  void _revealLabel() {
    _hideLabel?.cancel();
    setState(() => _showLabel = true);
    _hideLabel = Timer(_labelDuration, () {
      if (!mounted) return;
      setState(() => _showLabel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = deviceIsOnline(ref, widget.device);
    final color =
        online ? context.palette.statusOnline : context.colors.error;
    final label = online ? 'Online' : 'Offline';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeumorphicIconButton(
          icon: online ? Symbols.wifi : Symbols.wifi_off,
          iconColor: color,
          size: 40,
          iconSize: 20,
          tooltip: label,
          onPressed: _revealLabel,
        ),
        if (_showLabel) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: DeviceCardTextStyles.caption(context).copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
