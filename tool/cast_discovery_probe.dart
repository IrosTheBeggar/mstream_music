// Diagnostic: which network interfaces accept a multicast join on this box?
// multicast_dns joins on ALL interfaces and aborts if any one throws; on Windows
// virtual adapters (vEthernet/WSL/Hyper-V) often don't support it. This isolates
// the working interface(s) so the real discoverer can filter to them.
//
//   dart run tool/cast_discovery_probe.dart
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

final _mdns = InternetAddress('224.0.0.251');
const _service = '_googlecast._tcp.local';

Future<void> main() async {
  final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4, includeLoopback: false);
  stdout.writeln('IPv4 interfaces: ${ifaces.length}');
  final good = <NetworkInterface>[];
  for (final i in ifaces) {
    final addr = i.addresses.isNotEmpty ? i.addresses.first.address : '?';
    try {
      final s = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, 5353,
          reuseAddress: true, reusePort: false, ttl: 255);
      s.joinMulticast(_mdns, i);
      s.close();
      good.add(i);
      stdout.writeln('  OK   ${i.name}  ($addr)');
    } catch (e) {
      stdout.writeln('  FAIL ${i.name}  ($addr)  ${e.runtimeType}');
    }
  }
  stdout.writeln('Joinable interfaces: ${good.length}/${ifaces.length}');
  if (good.isEmpty) {
    stdout.writeln('No interface accepts a multicast join — pure-Dart '
        'joinMulticast is unavailable on this box.');
    return;
  }

  // Now run a real scan limited to the joinable interfaces.
  stdout.writeln('\nScanning ($_service) on joinable interfaces…');
  final client = MDnsClient(
    rawDatagramSocketFactory: (dynamic host, int port,
        {bool reuseAddress = true, bool reusePort = true, int ttl = 1}) {
      return RawDatagramSocket.bind(host, port,
          reuseAddress: reuseAddress, reusePort: false, ttl: ttl);
    },
  );
  await client.start(interfacesFactory: (type) async => good);
  var count = 0;
  try {
    await for (final ptr in client
        .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_service))
        .timeout(const Duration(seconds: 6), onTimeout: (s) => s.close())) {
      SrvResourceRecord? srv;
      await for (final r in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName))) {
        srv = r;
        break;
      }
      if (srv == null) continue;
      var name = srv.target;
      await for (final txt in client.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(ptr.domainName))) {
        for (final line in txt.text.split('\n')) {
          if (line.startsWith('fn=')) name = line.substring(3);
        }
        break;
      }
      InternetAddress? addr;
      await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target))) {
        addr = ip.address;
        break;
      }
      count++;
      stdout.writeln('  • $name → ${addr?.address ?? srv.target}:${srv.port}');
    }
  } finally {
    client.stop();
  }
  stdout.writeln(count == 0 ? 'No Cast devices answered.' : 'Found $count.');
}
