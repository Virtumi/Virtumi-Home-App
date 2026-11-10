import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/settings_forms/device_location_form.dart';

/// Device location assignment ("Geräte Ort").
class DeviceLocationPage extends ConsumerStatefulWidget {
  const DeviceLocationPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<DeviceLocationPage> createState() => _DeviceLocationPageState();
}

class _DeviceLocationPageState extends ConsumerState<DeviceLocationPage> {
  DeviceLocation? _draft;
  bool _editing = false;

  Future<void> _save(DeviceLocation base) async {
    final device = ref.read(deviceProvider(widget.deviceId)).value;
    final draft = _draft ?? base;
    final updated = device?.type == DeviceType.environmentMonitor
        ? draft.copyWith(deviceName: emsStoredName)
        : draft;
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveDeviceLocation(widget.deviceId, updated);
    await ref
        .read(smartHomeRepositoryProvider)
        .updateDeviceName(widget.deviceId, updated.deviceName);
    ref.invalidate(deviceLocationProvider(widget.deviceId));
    ref.invalidate(deviceProvider(widget.deviceId));
    if (mounted) {
      setState(() {
        _draft = null;
        _editing = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      _draft = null;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(deviceLocationProvider(widget.deviceId));
    final lockName = ref.watch(deviceProvider(widget.deviceId)).value?.type ==
        DeviceType.environmentMonitor;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () =>
            ref.invalidate(deviceLocationProvider(widget.deviceId)),
      ),
      body: AsyncValueView<DeviceLocation>(
        value: locationAsync,
        onRetry: () =>
            ref.invalidate(deviceLocationProvider(widget.deviceId)),
        data: (location) {
          final display = _editing ? (_draft ?? location) : location;
          return AppScrollView(
            children: [
              DeviceLocationForm(
                deviceId: widget.deviceId,
                location: display,
                lockDeviceName: lockName,
                enabled: _editing,
                onChanged: (loc) => setState(() => _draft = loc),
                footer: _editing
                    ? SaveCancelCard(
                        onCancel: _cancel,
                        onSave: () => _save(location),
                      )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
