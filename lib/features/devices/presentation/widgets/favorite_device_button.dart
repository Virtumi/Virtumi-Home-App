import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/neumorphic_icon_button.dart';
import '../../../../shared/application/favorite_devices.dart';

/// Heart button matching the online-status button: 40 px circle, 20 px icon.
class FavoriteDeviceButton extends ConsumerWidget {
  const FavoriteDeviceButton({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteDevicesProvider).contains(deviceId);

    return NeumorphicIconButton(
      icon: Symbols.favorite,
      iconColor: isFavorite
          ? context.palette.accentRed
          : context.colors.onSurface,
      size: 40,
      iconSize: 20,
      filled: isFavorite,
      tooltip: isFavorite ? 'Favorit entfernen' : 'Als Favorit speichern',
      onPressed: () =>
          ref.read(favoriteDevicesProvider.notifier).toggle(deviceId),
    );
  }
}
