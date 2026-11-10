import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/udp/device_endpoint_resolver.dart';
import '../data/udp/udp_device_service.dart';
import '../models/device.dart';
import '../providers/connection_mode_provider.dart';

/// Per-device UDP reachability while the app is in direct mode.
///
/// A missing entry means Online: switching to direct starts every device as
/// reachable until a request times out.
class DirectDeviceLinkNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.listen<bool>(isDirectConnectionProvider, (previous, next) {
      if (next) state = {};
    });
    return {};
  }

  void markOnline(String deviceId) {
    if (state[deviceId] == true) return;
    state = {...state, deviceId: true};
  }

  void markOffline(String deviceId) {
    if (state[deviceId] == false) return;
    state = {...state, deviceId: false};
  }
}

final directDeviceLinkProvider =
    NotifierProvider<DirectDeviceLinkNotifier, Map<String, bool>>(
  DirectDeviceLinkNotifier.new,
);

/// Cloud uses [Device.connectivity] from `livecom`. Direct mode uses the last
/// UDP result and treats an unknown device as Online.
bool deviceIsOnline(WidgetRef ref, Device device) {
  if (ref.watch(isDirectConnectionProvider)) {
    return ref.watch(directDeviceLinkProvider)[device.id] ?? true;
  }
  return device.connectivity == DeviceConnectivity.online;
}

const directProbeTimeout = Duration(seconds: 3);

/// Short UDP read for devices that do not already poll (control panel, switch,
/// blinds). A reply marks the device online; a timeout marks it offline.
Future<void> probeDirectDeviceLink({
  required DirectDeviceLinkNotifier link,
  required DeviceEndpointResolver resolver,
  required UdpDeviceService udp,
  required String deviceId,
}) async {
  try {
    final endpoint = await resolver.resolve(deviceId);
    await udp.readDeviceInfo(
      targetIp: endpoint.ipAddress,
      port: endpoint.port,
      deviceCode: endpoint.deviceCode,
      timeout: directProbeTimeout,
    );
    link.markOnline(deviceId);
  } catch (_) {
    link.markOffline(deviceId);
  }
}
