import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/data_providers.dart';
import 'widgets/device_settings_header.dart';

/// Read-only device information ("Geräte-Informationen").
class DeviceInfoPage extends ConsumerWidget {
  const DeviceInfoPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(deviceProvider(deviceId));
    final isDirect = ref.watch(isDirectConnectionProvider);
    final udpInfoAsync = isDirect
        ? ref.watch(deviceUdpLiveInfoProvider(deviceId))
        : null;
    final p = context.palette;

    Future<void> refresh() async {
      ref.invalidate(deviceProvider(deviceId));
      if (isDirect) {
        ref.invalidate(deviceUdpLiveInfoProvider(deviceId));
      }
    }

    return AppScaffold(
      header: AppHeader(onRefresh: refresh),
      body: AsyncValueView<Device?>(
        value: deviceAsync,
        onRetry: refresh,
        data: (device) {
          if (device == null) {
            return const EmptyState(
              icon: Symbols.error,
              message: 'Gerät nicht gefunden',
            );
          }

          final udpInfo = udpInfoAsync?.value;
          final udpType = udpInfo?['devicetype']?.toString();
          final isEms = device.type == DeviceType.environmentMonitor ||
              isEmsTypeName(udpType);
          final name = isEms
              ? emsDisplayName
              : (udpInfo?['devicename']?.toString() ?? device.displayName);
          final typeLabel = isEms
              ? emsDisplayName
              : (udpType ?? device.type.label);
          final hostname = udpInfo?['hostname']?.toString() ?? device.hostname;
          final ip = udpInfo?['ip_address']?.toString() ?? device.ipAddress;
          final mac = udpInfo?['mac_address']?.toString() ?? device.macAddress;
          final code = device.serialNumber;

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: deviceId,
                title: 'Geräte-Informationen',
                icon: Symbols.info,
              ),
              if (isDirect && udpInfoAsync != null && udpInfoAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (isDirect && udpInfoAsync?.hasError == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'UDP-Lese fehlgeschlagen: ${udpInfoAsync!.error}',
                    style: TextStyle(color: context.colors.error),
                  ),
                ),
              const AppSectionLabel('Allgemein'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.devices,
                    title: 'Name',
                    iconColor: p.accentBlue,
                    value: name,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.category,
                    title: 'Typ',
                    iconColor: p.accentIndigo,
                    value: typeLabel,
                  ),
                  _DeviceCodeRow(code: code, iconColor: p.accentTeal),
                ],
              ),
              const AppSectionLabel('System'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.dns,
                    title: 'Hostname',
                    iconColor: p.accentPurple,
                    value: hostname.isEmpty ? '—' : hostname,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.system_update,
                    title: 'Firmware',
                    iconColor: p.accentGreen,
                    value: device.firmwareVersion.isEmpty
                        ? '—'
                        : device.firmwareVersion,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.barcode,
                    title: 'Seriennummer',
                    iconColor: p.accentAmber,
                    value: device.hardwareSerial.isEmpty
                        ? '—'
                        : device.hardwareSerial,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.lan,
                    title: 'IP-Adresse',
                    iconColor: p.accentSky,
                    value: ip.isEmpty ? '—' : ip,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.cable,
                    title: 'MAC-Adresse',
                    iconColor: p.accentOrange,
                    value: mac.isEmpty ? '—' : mac,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCodeRow extends StatefulWidget {
  const _DeviceCodeRow({required this.code, required this.iconColor});

  final String code;
  final Color iconColor;

  @override
  State<_DeviceCodeRow> createState() => _DeviceCodeRowState();
}

class _DeviceCodeRowState extends State<_DeviceCodeRow> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    final hasCode = widget.code.isNotEmpty;
    final display = !hasCode
        ? '—'
        : _obscured
        ? '•' * widget.code.length
        : widget.code;

    return SettingsRow(
      icon: Symbols.tag,
      title: 'Code',
      iconColor: widget.iconColor,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              display,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: hasCode
                ? () => setState(() => _obscured = !_obscured)
                : null,
            icon: Icon(
              _obscured ? Symbols.visibility_off : Symbols.visibility,
              color: context.colors.onSurfaceVariant,
            ),
            tooltip: _obscured ? 'Code anzeigen' : 'Code verbergen',
          ),
        ],
      ),
    );
  }
}
