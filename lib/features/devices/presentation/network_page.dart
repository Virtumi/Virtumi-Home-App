import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/network_category_nav.dart';
import 'widgets/network_field_card.dart';

/// Network settings ("Netzwerk Konfiguration") with main categories,
/// sub-categories for WiFi AP/Station, and Save/Cancel in edit mode.
class NetworkPage extends ConsumerStatefulWidget {
  const NetworkPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends ConsumerState<NetworkPage> {
  NetworkMainCategory _mainCategory = NetworkMainCategory.modePort;
  NetworkSubCategory _subCategory = NetworkSubCategory.general;

  final _port = TextEditingController();
  final _apActiveConnections = TextEditingController();
  final _apSsid = TextEditingController();
  final _apPassword = TextEditingController();
  final _apChannel = TextEditingController();
  final _apDetailsPort = TextEditingController();
  final _apMac = TextEditingController();
  final _apIp = TextEditingController();
  final _apSubnet = TextEditingController();
  final _apGateway = TextEditingController();
  final _apDns = TextEditingController();
  final _apDhcpServer = TextEditingController();
  final _apWebServer = TextEditingController();
  final _stationActiveConnections = TextEditingController();
  final _stationSsid = TextEditingController();
  final _stationPassword = TextEditingController();
  final _stationChannel = TextEditingController();
  final _stationDetailsPort = TextEditingController();
  final _stationMac = TextEditingController();
  final _stationIp = TextEditingController();
  final _stationSubnet = TextEditingController();
  final _stationGateway = TextEditingController();
  final _stationDns = TextEditingController();
  final _stationDhcpServer = TextEditingController();
  final _stationWebServer = TextEditingController();
  final _stationWebServerStation = TextEditingController();

  bool _editing = false;
  bool _obscureAp = true;
  bool _obscureStation = true;
  bool _initialized = false;
  RealtimeService? _realtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!useSupabaseRealtime(ref)) return;
      _realtime = RealtimeService(ref.read(supabaseClientProvider));
      _realtime!.subscribeToDeviceTable(
        deviceId: widget.deviceId,
        table: 'device_network_settings',
        onChange: () => ref.invalidate(networkConfigProvider(widget.deviceId)),
      );
    });
  }

  @override
  void dispose() {
    _realtime?.unsubscribeAll();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  WifiOperatingMode _wifiMode = WifiOperatingMode.stationSoftAp;
  WifiEncryption _apEncryption = WifiEncryption.wpaPsk;
  IpMode _apIpMode = IpMode.dhcp;
  WifiEncryption _stationEncryption = WifiEncryption.open;
  IpMode _stationIpMode = IpMode.dhcp;

  Iterable<TextEditingController> get _controllers => [
        _port,
        _apActiveConnections,
        _apSsid,
        _apPassword,
        _apChannel,
        _apDetailsPort,
        _apMac,
        _apIp,
        _apSubnet,
        _apGateway,
        _apDns,
        _apDhcpServer,
        _apWebServer,
        _stationActiveConnections,
        _stationSsid,
        _stationPassword,
        _stationChannel,
        _stationDetailsPort,
        _stationMac,
        _stationIp,
        _stationSubnet,
        _stationGateway,
        _stationDns,
        _stationDhcpServer,
        _stationWebServer,
        _stationWebServerStation,
      ];

  void _hydrate(NetworkConfig config) {
    if (_initialized) return;
    _port.text = config.port;
    _apActiveConnections.text = config.apActiveConnections;
    _apSsid.text = config.apSsid;
    _apPassword.text = config.apPassword;
    _apChannel.text = config.apChannel;
    _apDetailsPort.text = config.apDetailsPort;
    _apMac.text = config.apMacAddress;
    _apIp.text = config.apIpAddress;
    _apSubnet.text = config.apSubnetMask;
    _apGateway.text = config.apGateway;
    _apDns.text = config.apDns;
    _apDhcpServer.text = config.apDhcpServerIp;
    _apWebServer.text = config.apWebServerIp;
    _stationActiveConnections.text = config.stationActiveConnections;
    _stationSsid.text = config.stationSsid;
    _stationPassword.text = config.stationPassword;
    _stationChannel.text = config.stationChannel;
    _stationDetailsPort.text = config.stationDetailsPort;
    _stationMac.text = config.stationMacAddress;
    _stationIp.text = config.stationIpAddress;
    _stationSubnet.text = config.stationSubnetMask;
    _stationGateway.text = config.stationGateway;
    _stationDns.text = config.stationDns;
    _stationDhcpServer.text = config.stationDhcpServerIp;
    _stationWebServer.text = config.stationWebServerIp;
    _stationWebServerStation.text = config.stationWebServerIpStation;
    _wifiMode = config.wifiMode;
    _apEncryption = config.apEncryption;
    _apIpMode = config.apIpMode;
    _stationEncryption = config.stationEncryption;
    _stationIpMode = config.stationIpMode;
    _initialized = true;
  }

  NetworkConfig _buildConfig(NetworkConfig base) {
    return base.copyWith(
      wifiMode: _wifiMode,
      port: _port.text.trim(),
      apActiveConnections: _apActiveConnections.text.trim(),
      apSsid: _apSsid.text.trim(),
      apPassword: _apPassword.text,
      apChannel: _apChannel.text.trim(),
      apEncryption: _apEncryption,
      apDetailsPort: _apDetailsPort.text.trim(),
      apIpMode: _apIpMode,
      apMacAddress: _apMac.text.trim(),
      apIpAddress: _apIp.text.trim(),
      apSubnetMask: _apSubnet.text.trim(),
      apGateway: _apGateway.text.trim(),
      apDns: _apDns.text.trim(),
      apDhcpServerIp: _apDhcpServer.text.trim(),
      apWebServerIp: _apWebServer.text.trim(),
      stationActiveConnections: _stationActiveConnections.text.trim(),
      stationSsid: _stationSsid.text.trim(),
      stationPassword: _stationPassword.text,
      stationChannel: _stationChannel.text.trim(),
      stationEncryption: _stationEncryption,
      stationDetailsPort: _stationDetailsPort.text.trim(),
      stationIpMode: _stationIpMode,
      stationMacAddress: _stationMac.text.trim(),
      stationIpAddress: _stationIp.text.trim(),
      stationSubnetMask: _stationSubnet.text.trim(),
      stationGateway: _stationGateway.text.trim(),
      stationDns: _stationDns.text.trim(),
      stationDhcpServerIp: _stationDhcpServer.text.trim(),
      stationWebServerIp: _stationWebServer.text.trim(),
      stationWebServerIpStation: _stationWebServerStation.text.trim(),
    );
  }

  Future<void> _save(NetworkConfig base) async {
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveNetworkConfig(widget.deviceId, _buildConfig(base));
    ref.invalidate(networkConfigProvider(widget.deviceId));
    if (mounted) setState(() => _editing = false);
  }

  void _cancel(NetworkConfig config) {
    _initialized = false;
    _hydrate(config);
    setState(() => _editing = false);
  }

  void _selectMainCategory(NetworkMainCategory category) {
    setState(() {
      _mainCategory = category;
      if (category != NetworkMainCategory.modePort) {
        _subCategory = NetworkSubCategory.general;
      }
    });
  }

  Future<void> _pickWifiMode() async {
    if (!_editing) return;
    final result = await showOptionPicker<WifiOperatingMode>(
      context: context,
      title: 'WiFi Modus',
      options: WifiOperatingMode.values,
      labelOf: (mode) => mode.label,
      selected: _wifiMode,
    );
    if (result != null) setState(() => _wifiMode = result);
  }

  Future<void> _pickApEncryption() async {
    if (!_editing) return;
    final result = await showOptionPicker<WifiEncryption>(
      context: context,
      title: 'ENC',
      options: WifiEncryption.values,
      labelOf: (enc) => enc.label,
      selected: _apEncryption,
    );
    if (result != null) setState(() => _apEncryption = result);
  }

  Future<void> _pickApIpMode() async {
    if (!_editing) return;
    final result = await showOptionPicker<IpMode>(
      context: context,
      title: 'Netzwerk Typ',
      options: IpMode.values,
      labelOf: (mode) => mode == IpMode.dhcp ? 'DHCP' : 'Manuell',
      selected: _apIpMode,
    );
    if (result != null) setState(() => _apIpMode = result);
  }

  Future<void> _pickStationEncryption() async {
    if (!_editing) return;
    final result = await showOptionPicker<WifiEncryption>(
      context: context,
      title: 'ENC',
      options: WifiEncryption.values,
      labelOf: (enc) => enc.label,
      selected: _stationEncryption,
    );
    if (result != null) setState(() => _stationEncryption = result);
  }

  Future<void> _pickStationIpMode() async {
    if (!_editing) return;
    final result = await showOptionPicker<IpMode>(
      context: context,
      title: 'Netzwerk Typ',
      options: IpMode.values,
      labelOf: (mode) => mode == IpMode.dhcp ? 'DHCP' : 'Manuell',
      selected: _stationIpMode,
    );
    if (result != null) setState(() => _stationIpMode = result);
  }

  Widget _twoColumn(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildModePortSection(AppPalette p) {
    return Column(
      children: [
        NetworkPickerCard(
          icon: Symbols.settings,
          iconColor: p.accentBlue,
          label: 'WiFi Modus',
          value: _wifiMode.label,
          onTap: _editing ? _pickWifiMode : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.dns,
          iconColor: p.accentIndigo,
          label: 'Port',
          controller: _port,
          enabled: _editing,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildApGeneralSection(AppPalette p) {
    return Column(
      children: [
        NetworkFieldCard(
          icon: Symbols.wifi,
          iconColor: p.accentSky,
          label: 'Aktive Verbindungen',
          controller: _apActiveConnections,
          enabled: _editing,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.account_tree,
          iconColor: p.accentTeal,
          label: 'SSID',
          controller: _apSsid,
          enabled: _editing,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.settings,
          iconColor: p.accentOrange,
          label: 'Passwort',
          controller: _apPassword,
          enabled: _editing,
          obscure: _obscureAp,
          onToggleObscure: () => setState(() => _obscureAp = !_obscureAp),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.router,
            iconColor: p.accentPurple,
            label: 'Kanal',
            controller: _apChannel,
            enabled: _editing,
            keyboardType: TextInputType.number,
          ),
          NetworkPickerCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'ENC',
            value: _apEncryption.label,
            onTap: _editing ? _pickApEncryption : null,
          ),
        ),
      ],
    );
  }

  Widget _buildApDetailsSection(AppPalette p) {
    return Column(
      children: [
        NetworkFieldCard(
          icon: Symbols.dns,
          iconColor: p.accentIndigo,
          label: 'Port',
          controller: _apDetailsPort,
          enabled: _editing,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkPickerCard(
          icon: Symbols.account_tree,
          iconColor: p.accentTeal,
          label: 'Netzwerk Typ',
          value: _apIpMode == IpMode.dhcp ? 'DHCP' : 'Manuell',
          onTap: _editing ? _pickApIpMode : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.settings,
          iconColor: p.accentBlue,
          label: 'MAC Adresse',
          controller: _apMac,
          enabled: _editing,
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'IP Adresse',
            controller: _apIp,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.router,
            iconColor: p.accentPurple,
            label: 'Netzmaske',
            controller: _apSubnet,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.dns,
            iconColor: p.accentIndigo,
            label: 'Gateway IP',
            controller: _apGateway,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.wifi,
            iconColor: p.accentSky,
            label: 'DNS IP',
            controller: _apDns,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.settings,
            iconColor: p.accentOrange,
            label: 'DHCP Server IP',
            controller: _apDhcpServer,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'Web Server IP',
            controller: _apWebServer,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStationGeneralSection(AppPalette p) {
    return Column(
      children: [
        NetworkFieldCard(
          icon: Symbols.wifi,
          iconColor: p.accentSky,
          label: 'Aktive Verbindungen',
          controller: _stationActiveConnections,
          enabled: _editing,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.account_tree,
          iconColor: p.accentTeal,
          label: 'SSID',
          controller: _stationSsid,
          enabled: _editing,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.settings,
          iconColor: p.accentOrange,
          label: 'Passwort',
          controller: _stationPassword,
          enabled: _editing,
          obscure: _obscureStation,
          onToggleObscure: () =>
              setState(() => _obscureStation = !_obscureStation),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.router,
            iconColor: p.accentPurple,
            label: 'Kanal',
            controller: _stationChannel,
            enabled: _editing,
            keyboardType: TextInputType.number,
          ),
          NetworkPickerCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'ENC',
            value: _stationEncryption.label,
            onTap: _editing ? _pickStationEncryption : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStationDetailsSection(AppPalette p) {
    return Column(
      children: [
        NetworkFieldCard(
          icon: Symbols.dns,
          iconColor: p.accentIndigo,
          label: 'Port',
          controller: _stationDetailsPort,
          enabled: _editing,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkPickerCard(
          icon: Symbols.account_tree,
          iconColor: p.accentTeal,
          label: 'Netzwerk Typ',
          value: _stationIpMode == IpMode.dhcp ? 'DHCP' : 'Manuell',
          onTap: _editing ? _pickStationIpMode : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.settings,
          iconColor: p.accentBlue,
          label: 'MAC Adresse',
          controller: _stationMac,
          enabled: _editing,
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'IP Adresse',
            controller: _stationIp,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.router,
            iconColor: p.accentPurple,
            label: 'Netzmaske',
            controller: _stationSubnet,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.dns,
            iconColor: p.accentIndigo,
            label: 'Gateway IP',
            controller: _stationGateway,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.wifi,
            iconColor: p.accentSky,
            label: 'DNS IP',
            controller: _stationDns,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _twoColumn(
          NetworkFieldCard(
            icon: Symbols.settings,
            iconColor: p.accentOrange,
            label: 'DHCP Server IP',
            controller: _stationDhcpServer,
            enabled: _editing,
            keyboardType: TextInputType.number,
            compactValue: true,
          ),
          NetworkFieldCard(
            icon: Symbols.public,
            iconColor: p.accentGreen,
            label: 'Web Server IP',
            controller: _stationWebServer,
            enabled: _editing,
            keyboardType: TextInputType.number,
            hint: 'Web Server IP',
            compactValue: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        NetworkFieldCard(
          icon: Symbols.dns,
          iconColor: p.accentIndigo,
          label: 'Web Server IP (Station)',
          controller: _stationWebServerStation,
          enabled: _editing,
          keyboardType: TextInputType.number,
          hint: 'Web Server IP (Station)',
        ),
      ],
    );
  }

  Widget _buildContent(AppPalette p) {
    switch (_mainCategory) {
      case NetworkMainCategory.modePort:
        return _buildModePortSection(p);
      case NetworkMainCategory.wifiAp:
        return _subCategory == NetworkSubCategory.general
            ? _buildApGeneralSection(p)
            : _buildApDetailsSection(p);
      case NetworkMainCategory.wifiStation:
        return _subCategory == NetworkSubCategory.general
            ? _buildStationGeneralSection(p)
            : _buildStationDetailsSection(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(networkConfigProvider(widget.deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () =>
            ref.invalidate(networkConfigProvider(widget.deviceId)),
      ),
      body: AsyncValueView<NetworkConfig>(
        value: configAsync,
        onRetry: () =>
            ref.invalidate(networkConfigProvider(widget.deviceId)),
        data: (config) {
          _hydrate(config);
          final showSubNav = _mainCategory != NetworkMainCategory.modePort;

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: widget.deviceId,
                title: 'Netzwerk Konfiguration',
                icon: Symbols.wifi,
              ),
              NetworkCategoryNav(
                selected: _mainCategory,
                onSelected: _selectMainCategory,
              ),
              if (showSubNav) ...[
                const SizedBox(height: AppSpacing.md),
                NetworkSubCategoryNav(
                  selected: _subCategory,
                  onSelected: (category) =>
                      setState(() => _subCategory = category),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _buildContent(p),
              if (_editing)
                SaveCancelCard(
                  onCancel: () => _cancel(config),
                  onSave: () => _save(config),
                ),
            ],
          );
        },
      ),
    );
  }
}
