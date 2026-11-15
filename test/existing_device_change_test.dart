import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/features/add_device/models/existing_device_change.dart';

ExistingDeviceChange _change({
  String storedIp = '192.168.1.10',
  String foundIp = '192.168.1.10',
  DevicePlace storedPlace = const DevicePlace(
    home: 'Haus',
    floor: 'EG',
    room: 'Wohnzimmer',
  ),
  DevicePlace foundPlace = const DevicePlace(
    home: 'Haus',
    floor: 'EG',
    room: 'Wohnzimmer',
  ),
}) {
  return ExistingDeviceChange(
    deviceId: 'id',
    deviceName: 'Panel',
    storedIp: storedIp,
    foundIp: foundIp,
    storedPlace: storedPlace,
    foundPlace: foundPlace,
  );
}

void main() {
  test('everything equal: no change', () {
    final c = _change();
    expect(c.ipChanged, isFalse);
    expect(c.locationChanged, isFalse);
    expect(c.hasChanges, isFalse);
  });

  test('only IP differs', () {
    final c = _change(foundIp: '192.168.1.55');
    expect(c.ipChanged, isTrue);
    expect(c.locationChanged, isFalse);
  });

  test('only place differs', () {
    final c = _change(
      foundPlace: const DevicePlace(
        home: 'Haus',
        floor: 'OG',
        room: 'Schlafzimmer',
      ),
    );
    expect(c.ipChanged, isFalse);
    expect(c.locationChanged, isTrue);
  });

  test('IP and place differ', () {
    final c = _change(
      foundIp: '10.0.0.2',
      foundPlace: const DevicePlace(home: 'Ferienhaus', floor: 'EG', room: 'Bad'),
    );
    expect(c.ipChanged, isTrue);
    expect(c.locationChanged, isTrue);
    expect(c.hasChanges, isTrue);
  });

  test('place comparison ignores case and whitespace', () {
    final c = _change(
      foundPlace: const DevicePlace(
        home: ' haus ',
        floor: 'eg',
        room: 'WOHNZIMMER',
      ),
    );
    expect(c.locationChanged, isFalse);
  });

  test('unknown place of the device is not a change', () {
    final c = _change(foundPlace: const DevicePlace());
    expect(c.locationChanged, isFalse);
  });

  test('unknown found IP is not a change', () {
    final c = _change(foundIp: '');
    expect(c.ipChanged, isFalse);
  });

  test('place label joins non-empty parts', () {
    expect(
      const DevicePlace(home: 'Haus', floor: '', room: 'Bad').label,
      'Haus / Bad',
    );
    expect(const DevicePlace().label, '-');
  });
}
