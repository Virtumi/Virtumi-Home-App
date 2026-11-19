import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/shared/data/udp/udp_mappers.dart';
import 'package:virtumi_home/shared/models/cp_parameter.dart';

void main() {
  test('UDP write payload uses the 0-based firmware slot', () {
    const parameter = CpParameter(
      parameterIndex: 0,
      active: 1,
      enabled: 1,
      mode: 2,
      macAddress: 'AA:BB:CC:DD:EE:FF',
      ipAddress: '192.168.1.20',
      port: 4210,
      name: 'Lampe',
      code: 'led-code',
      resourceName: 'lampe',
      deviceType: 3,
      command0Active: 1,
      command0Exists: 1,
      command0Function: 2,
      command0ProtokolNr: 100,
      command1Active: 0,
      command1Function: 4,
      command2Active: 1,
      command2Exists: 1,
      command2Function: 5,
      command2ProtokolNr: 100,
    );

    final payload = cpParameterUdpWritePayload('panel-code', parameter);

    expect(payload['command'], 0);
    expect(payload['command'], isNot(parameter.parameterIndex + 1));
    expect(payload['code'], 'panel-code');
    expect(payload['device_code'], 'led-code');
    expect(payload['port'], 4210);
    expect(payload['device_type'], 3);
    expect(payload['resource_name'], 'lampe');

    final commands = payload['commands'] as List<dynamic>;
    expect(commands, hasLength(3));
    expect(commands[0], {
      'active': 1,
      'exists': 1,
      'function': 2,
      'protokol_nr': 100,
    });
    expect(commands[2]['function'], 5);
  });

  test('UDP read maps port onto the requested slot', () {
    final parameter = mapCpParameterFromUdp({
      'active': 1,
      'enabled': 1,
      'port': 4210,
      'name': 'Lampe',
    }, 4);

    expect(parameter.parameterIndex, 4);
    expect(parameter.port, 4210);
    expect(parameter.active, 1);
  });
}
