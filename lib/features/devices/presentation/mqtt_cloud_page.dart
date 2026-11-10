import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/connection_status_card.dart';
import 'widgets/device_settings_header.dart';

/// MQTT broker settings ("MQTT Cloud").
class MqttCloudPage extends ConsumerStatefulWidget {
  const MqttCloudPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<MqttCloudPage> createState() => _MqttCloudPageState();
}

class _MqttCloudPageState extends ConsumerState<MqttCloudPage> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _customerNumber = TextEditingController();

  bool _editing = false;
  bool _obscure = true;
  bool _initialized = false;
  bool _enabled = false;
  bool _allowAnonymous = false;
  MqttQosLevel _qosLevel = MqttQosLevel.atMostOnce;
  bool _retainMessages = false;
  bool _cleanSession = true;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _resetting = false;

  @override
  void dispose() {
    for (final c in [_host, _port, _username, _password, _customerNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(MqttCloudConfig config) {
    if (_initialized) return;
    _host.text = config.host;
    _port.text = '${config.port}';
    _username.text = config.username;
    _password.text = config.password;
    _customerNumber.text = config.customerNumber;
    _enabled = config.enabled;
    _allowAnonymous = config.allowAnonymous;
    _qosLevel = config.qosLevel;
    _retainMessages = config.retainMessages;
    _cleanSession = config.cleanSession;
    _status = config.status;
    _initialized = true;
  }

  MqttCloudConfig _buildConfig(MqttCloudConfig base) {
    return base.copyWith(
      enabled: _enabled,
      status: _status,
      host: _host.text.trim(),
      port: int.tryParse(_port.text) ?? base.port,
      username: _username.text.trim(),
      password: _password.text,
      allowAnonymous: _allowAnonymous,
      customerNumber: _customerNumber.text.trim(),
      qosLevel: _qosLevel,
      retainMessages: _retainMessages,
      cleanSession: _cleanSession,
    );
  }

  Future<void> _persistMqtt(MqttCloudConfig mqtt) async {
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveMqttCloud(widget.deviceId, mqtt);
    ref.invalidate(cloudConfigProvider(widget.deviceId));
  }

  Future<void> _save(CloudConfig cloud) async {
    await _persistMqtt(_buildConfig(cloud.mqtt));
    if (mounted) setState(() => _editing = false);
  }

  void _cancel(MqttCloudConfig config) {
    _initialized = false;
    _resetting = false;
    _hydrate(config);
    setState(() => _editing = false);
  }

  Future<bool?> _pickYesNo(String title, bool current) {
    return showOptionPicker<bool>(
      context: context,
      title: title,
      options: const [true, false],
      labelOf: (value) => value ? 'Ja' : 'Nein',
      selected: current,
    );
  }

  Future<void> _pickAllowAnonymous() async {
    if (!_editing) return;
    final result = await _pickYesNo('Anonyme Verbindung erlauben', _allowAnonymous);
    if (result != null) setState(() => _allowAnonymous = result);
  }

  Future<void> _pickQosLevel() async {
    if (!_editing) return;
    final result = await showOptionPicker<MqttQosLevel>(
      context: context,
      title: 'QoS Level',
      options: MqttQosLevel.values,
      labelOf: (level) => level.label,
      selected: _qosLevel,
    );
    if (result != null) setState(() => _qosLevel = result);
  }

  Future<void> _pickRetainMessages() async {
    if (!_editing) return;
    final result = await _pickYesNo('Retain Messages', _retainMessages);
    if (result != null) setState(() => _retainMessages = result);
  }

  Future<void> _pickCleanSession() async {
    if (!_editing) return;
    final result = await _pickYesNo('Clean Session', _cleanSession);
    if (result != null) setState(() => _cleanSession = result);
  }

  Future<void> _resetBroker(CloudConfig cloud) async {
    if (_resetting) return;
    setState(() {
      _resetting = true;
      _status = ConnectionStatus.connecting;
    });

    await _persistMqtt(
      cloud.mqtt.copyWith(status: ConnectionStatus.connecting),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final nextStatus = _enabled && _host.text.trim().isNotEmpty
        ? ConnectionStatus.connected
        : ConnectionStatus.disconnected;

    setState(() {
      _status = nextStatus;
      _resetting = false;
    });

    await _persistMqtt(cloud.mqtt.copyWith(status: nextStatus));
  }

  @override
  Widget build(BuildContext context) {
    final cloudAsync = ref.watch(cloudConfigProvider(widget.deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () => ref.invalidate(cloudConfigProvider(widget.deviceId)),
      ),
      body: AsyncValueView<CloudConfig>(
        value: cloudAsync,
        onRetry: () => ref.invalidate(cloudConfigProvider(widget.deviceId)),
        data: (cloud) {
          _hydrate(cloud.mqtt);
          if (!_resetting && !_editing) {
            _status = cloud.mqtt.status;
          }
          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: widget.deviceId,
                title: 'MQTT Cloud',
                icon: Symbols.dns,
                accent: AppColors.accentPurple,
              ),
              ConnectionStatusCard(
                status: _status,
                title: 'Broker Status',
                onReset: _status == ConnectionStatus.disconnected
                    ? () => _resetBroker(cloud)
                    : null,
              ),
              const AppSectionLabel('Verbindung'),
              GroupedListCard(
                children: [
                  SettingsRow.toggle(
                    icon: Symbols.toggle_on,
                    title: 'MQTT aktiviert',
                    iconColor: p.accentPurple,
                    value: _enabled,
                    onChanged: _editing
                        ? (v) => setState(() => _enabled = v)
                        : (_) {},
                  ),
                  SettingsInputRow(
                    icon: Symbols.dns,
                    label: 'Host',
                    controller: _host,
                    iconColor: p.accentBlue,
                    enabled: _editing,
                  ),
                  SettingsInputRow(
                    icon: Symbols.settings_ethernet,
                    label: 'Port',
                    controller: _port,
                    iconColor: p.accentTeal,
                    enabled: _editing,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const AppSectionLabel('Authentifizierung'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.person_off,
                    title: 'Anonyme Verbindung erlauben',
                    iconColor: p.accentSky,
                    value: _allowAnonymous ? 'Ja' : 'Nein',
                    onTap: _editing ? _pickAllowAnonymous : null,
                  ),
                  SettingsInputRow(
                    icon: Symbols.person,
                    label: 'Benutzername',
                    controller: _username,
                    iconColor: p.accentIndigo,
                    enabled: _editing && !_allowAnonymous,
                  ),
                  SettingsInputRow(
                    icon: Symbols.lock,
                    label: 'Passwort',
                    controller: _password,
                    iconColor: p.accentOrange,
                    enabled: _editing && !_allowAnonymous,
                    obscure: _obscure,
                    onToggleObscure: _editing && !_allowAnonymous
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                  ),
                ],
              ),
              const AppSectionLabel('Kundeninformationen'),
              GroupedListCard(
                children: [
                  SettingsInputRow(
                    icon: Symbols.badge,
                    label: 'Kundennummer',
                    controller: _customerNumber,
                    iconColor: p.accentBlue,
                    enabled: _editing,
                    hint: 'z. B. virtumihome_Smart_LED',
                  ),
                ],
              ),
              const AppSectionLabel('MQTT Einstellungen'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.low_priority,
                    title: 'QoS Level',
                    iconColor: p.accentIndigo,
                    value: _qosLevel.label,
                    onTap: _editing ? _pickQosLevel : null,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.bookmark,
                    title: 'Retain Messages',
                    iconColor: p.accentOrange,
                    value: _retainMessages ? 'Ja' : 'Nein',
                    onTap: _editing ? _pickRetainMessages : null,
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.cleaning_services,
                    title: 'Clean Session',
                    iconColor: p.accentTeal,
                    value: _cleanSession ? 'Ja' : 'Nein',
                    onTap: _editing ? _pickCleanSession : null,
                  ),
                ],
              ),
              if (_editing)
                SaveCancelCard(
                  onCancel: () => _cancel(cloud.mqtt),
                  onSave: () => _save(cloud),
                ),
            ],
          );
        },
      ),
    );
  }
}
