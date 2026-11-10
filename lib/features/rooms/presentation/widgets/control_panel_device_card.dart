import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/application/direct_device_link.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/repository_providers.dart';
import 'device_card_text_styles.dart';
import 'device_online_badge.dart';

/// Room card for control panel devices: header actions plus Links/Mitte/Rechts
/// zone selector with cloud button press (cp_btn_requests).
class ControlPanelDeviceCard extends ConsumerStatefulWidget {
  const ControlPanelDeviceCard({
    super.key,
    required this.device,
    required this.onOpenDetails,
    required this.onOpenSettings,
    this.showSettingsButton = true,
    this.showDetailsButton = true,
  });

  final Device device;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSettings;
  final bool showSettingsButton;
  final bool showDetailsButton;

  @override
  ConsumerState<ControlPanelDeviceCard> createState() =>
      _ControlPanelDeviceCardState();
}

class _ControlPanelDeviceCardState extends ConsumerState<ControlPanelDeviceCard> {
  ControlPanelPosition _position = ControlPanelPosition.center;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deviceEndpointResolverProvider).cacheFromDevice(widget.device);
    });
  }

  @override
  void didUpdateWidget(covariant ControlPanelDeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id ||
        oldWidget.device.ipAddress != widget.device.ipAddress ||
        oldWidget.device.serialNumber != widget.device.serialNumber) {
      ref.read(deviceEndpointResolverProvider).cacheFromDevice(widget.device);
    }
  }

  void _sendPress(ControlPanelPosition position) {
    setState(() => _position = position);
    unawaited(() async {
      try {
        await ref
            .read(deviceRequestRepositoryProvider)
            .sendButtonPress(widget.device.id, position.command);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final online = deviceIsOnline(ref, widget.device);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(
                icon: widget.device.type.icon,
                color: primary,
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
                      widget.device.name,
                      style: DeviceCardTextStyles.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.device.type.label,
                      style: DeviceCardTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
              DeviceOnlineBadge(device: widget.device),
              if (online && widget.showSettingsButton) ...[
                const SizedBox(width: AppSpacing.sm),
                NeumorphicIconButton(
                  icon: Symbols.settings,
                  iconColor: context.colors.onSurface,
                  size: 40,
                  iconSize: 20,
                  tooltip: 'Geräteeinstellungen',
                  onPressed: widget.onOpenSettings,
                ),
              ],
              if (online &&
                  widget.showSettingsButton &&
                  widget.showDetailsButton)
                const SizedBox(width: AppSpacing.sm),
              if (online && widget.showDetailsButton)
                _PrimaryNavButton(onPressed: widget.onOpenDetails),
            ],
          ),
          if (online) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PanelZoneButton(
                label: ControlPanelPosition.left.label,
                icon: Symbols.chevron_left,
                selected: _position == ControlPanelPosition.left,
                onTap: () => _sendPress(ControlPanelPosition.left),
              ),
              _PanelZoneButton(
                label: ControlPanelPosition.center.label,
                icon: Symbols.panorama_fish_eye,
                selected: _position == ControlPanelPosition.center,
                prominent: true,
                onTap: () => _sendPress(ControlPanelPosition.center),
              ),
              _PanelZoneButton(
                label: ControlPanelPosition.right.label,
                icon: Symbols.chevron_right,
                selected: _position == ControlPanelPosition.right,
                onTap: () => _sendPress(ControlPanelPosition.right),
              ),
            ],
          ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryNavButton extends StatelessWidget {
  const _PrimaryNavButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return PressScale(
      style: PressScaleStyle.compact,
      onTap: onPressed,
      semanticLabel: 'Gerätedetails',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Symbols.arrow_forward,
          color: context.colors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _PanelZoneButton extends StatelessWidget {
  const _PanelZoneButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final inactive = context.colors.onSurface;
    final size = prominent && selected ? 56.0 : 48.0;
    final iconSize = prominent && selected ? 28.0 : 24.0;

    Widget circle;
    if (selected) {
      circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: context.colors.onPrimary,
          size: iconSize,
        ),
      );
    } else {
      circle = NeumorphicContainer(
        style: NeumorphicStyle.raised,
        color: context.palette.controlSurface,
        width: size,
        height: size,
        borderRadius: AppRadius.full,
        alignment: Alignment.center,
        child: Icon(icon, color: inactive, size: iconSize),
      );
    }

    return PressScale(
      style: PressScaleStyle.compact,
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: DeviceCardTextStyles.caption(
              context,
              emphasis: selected,
            ),
          ),
        ],
      ),
    );
  }
}
