import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../device_settings_header.dart';
import '../location_field_card.dart';
import '../location_name_input.dart';

class DeviceLocationForm extends StatefulWidget {
  const DeviceLocationForm({
    super.key,
    required this.location,
    required this.enabled,
    required this.onChanged,
    this.footer,
    this.lockDeviceName = false,
    this.deviceId,
  });

  final DeviceLocation location;
  final bool enabled;
  final ValueChanged<DeviceLocation> onChanged;
  final Widget? footer;

  /// EMS keeps the stored name `EMS` and shows the long display name.
  final bool lockDeviceName;

  /// Set on the device settings page. The setup wizard leaves this empty.
  final String? deviceId;

  @override
  State<DeviceLocationForm> createState() => _DeviceLocationFormState();
}

class _DeviceLocationFormState extends State<DeviceLocationForm> {
  final _deviceName = TextEditingController();
  final _house = TextEditingController();
  final _floor = TextEditingController();
  final _room = TextEditingController();
  String _houseIconKey = LocationPresets.house.first.key;
  String _floorIconKey = LocationPresets.floor.first.key;
  String _roomIconKey = LocationPresets.room.first.key;

  @override
  void initState() {
    super.initState();
    for (final c in [_deviceName, _house, _floor, _room]) {
      c.addListener(_emit);
    }
    _applyLocation(widget.location);
  }

  @override
  void didUpdateWidget(covariant DeviceLocationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_matchesControllers(widget.location)) return;
    if (_locationsEqual(oldWidget.location, widget.location)) return;
    _applyLocation(widget.location);
  }

  bool _locationsEqual(DeviceLocation a, DeviceLocation b) {
    return a.deviceName == b.deviceName &&
        a.houseName == b.houseName &&
        a.houseIconKey == b.houseIconKey &&
        a.floorName == b.floorName &&
        a.floorIconKey == b.floorIconKey &&
        a.roomName == b.roomName &&
        a.roomIconKey == b.roomIconKey &&
        a.note == b.note;
  }

  bool _matchesControllers(DeviceLocation loc) {
    final shownName = _nameLocked ? emsDisplayName : loc.deviceName;
    return shownName == _deviceName.text.trim() &&
        loc.houseName == _house.text.trim() &&
        loc.houseIconKey == _houseIconKey &&
        loc.floorName == _floor.text.trim() &&
        loc.floorIconKey == _floorIconKey &&
        loc.roomName == _room.text.trim() &&
        loc.roomIconKey == _roomIconKey &&
        loc.note == widget.location.note;
  }

  bool get _nameLocked =>
      widget.lockDeviceName || isEmsStoredName(widget.location.deviceName);

  void _applyLocation(DeviceLocation loc) {
    _withoutEmit(() {
      _deviceName.text = _nameLocked ? emsDisplayName : loc.deviceName;
      _house.text = loc.houseName;
      _floor.text = loc.floorName;
      _room.text = loc.roomName;
      _houseIconKey = loc.houseIconKey;
      _floorIconKey = loc.floorIconKey;
      _roomIconKey = loc.roomIconKey;
    });
  }

  void _withoutEmit(VoidCallback fn) {
    for (final c in [_deviceName, _house, _floor, _room]) {
      c.removeListener(_emit);
    }
    fn();
    for (final c in [_deviceName, _house, _floor, _room]) {
      c.addListener(_emit);
    }
  }

  void _emit() {
    widget.onChanged(
      widget.location.copyWith(
        deviceName: _nameLocked ? emsStoredName : _deviceName.text.trim(),
        houseName: _house.text.trim(),
        houseIconKey: _houseIconKey,
        floorName: _floor.text.trim(),
        floorIconKey: _floorIconKey,
        roomName: _room.text.trim(),
        roomIconKey: _roomIconKey,
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [_deviceName, _house, _floor, _room]) {
      c.removeListener(_emit);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.deviceId != null)
          DeviceSettingsHeader(
            deviceId: widget.deviceId!,
            title: 'Geräte Ort',
            icon: Symbols.location_on,
            accent: AppColors.accentOrange,
          )
        else
          const SectionHeaderCard(
            title: 'Geräte Ort',
            subtitle: 'Standort-Zuordnung',
            icon: Symbols.location_on,
            accent: AppColors.accentOrange,
            filled: true,
          ),
        const AppSectionLabel('Gerätename'),
        GroupedListCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LocationNameInput(
                icon: _nameLocked ? Symbols.air : Symbols.tablet,
                iconColor: p.accentBlue,
                controller: _deviceName,
                enabled: widget.enabled && !_nameLocked,
                hint: 'z. B. My Control Panel',
              ),
            ),
          ],
        ),
        const AppSectionLabel('Zuordnung'),
        LocationFieldCard(
          label: 'Haus',
          nameController: _house,
          selectedIconKey: _houseIconKey,
          presets: LocationPresets.house,
          iconColor: p.accentBlue,
          enabled: widget.enabled,
          onIconKeyChanged: (key) {
            setState(() => _houseIconKey = key);
            _emit();
          },
          hint: 'z. B. Haus, Garten',
        ),
        const SizedBox(height: AppSpacing.md),
        LocationFieldCard(
          label: 'Etage',
          nameController: _floor,
          selectedIconKey: _floorIconKey,
          presets: LocationPresets.floor,
          iconColor: p.accentIndigo,
          enabled: widget.enabled,
          onIconKeyChanged: (key) {
            setState(() => _floorIconKey = key);
            _emit();
          },
          hint: 'z. B. Erdgeschoss, Keller',
        ),
        const SizedBox(height: AppSpacing.md),
        LocationFieldCard(
          label: 'Raum',
          nameController: _room,
          selectedIconKey: _roomIconKey,
          presets: LocationPresets.room,
          iconColor: p.accentTeal,
          enabled: widget.enabled,
          onIconKeyChanged: (key) {
            setState(() => _roomIconKey = key);
            _emit();
          },
          hint: 'z. B. Wohnzimmer, Küche',
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}
