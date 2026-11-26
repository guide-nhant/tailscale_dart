@TestOn('mac-os || linux')
library;

import 'package:tailscale/src/api/connection.dart';
import 'package:tailscale/src/api/udp.dart';
import 'package:tailscale/src/errors.dart';
import 'package:test/test.dart';

void main() {
  const local = TailscaleEndpoint(address: '100.64.0.1', port: 40000);

  test('Udp.bindFd returns the Go bridge bindingId with the fd', () async {
    final udp = createUdp(
      bindFn: (host, port) async {
        expect(host, '');
        expect(port, 0);
        return (fd: 42, bindingId: 7, local: local);
      },
      closeFn: (_) => throw StateError('not called'),
    );

    final endpoint = await udp.bindFd(port: 0);

    expect(endpoint.fd, 42);
    expect(endpoint.bindingId, 7);
    expect(endpoint.local, local);
    expect(endpoint.remote, isNull);
  });

  test('Udp.closeFdBinding closes the Go bridge by id', () async {
    final closed = <int>[];
    final udp = createUdp(
      bindFn: (_, _) async => (fd: 42, bindingId: 9, local: local),
      closeFn: (id) async => closed.add(id),
    );

    final endpoint = await udp.bindFd(port: 0, address: '100.64.0.1');
    await udp.closeFdBinding(endpoint.bindingId!);

    expect(closed, [9]);
  });

  test('Udp.closeFdBinding wraps close failures', () async {
    final udp = createUdp(
      bindFn: (_, _) => throw StateError('not called'),
      closeFn: (_) async => throw StateError('worker gone'),
    );

    await expectLater(
      udp.closeFdBinding(3),
      throwsA(
        isA<TailscaleUdpException>()
            .having(
              (e) => e.message,
              'message',
              'udp.closeFdBinding failed for binding 3',
            )
            .having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );
  });

  test('TailscaleFdEndpoint equality includes bindingId', () {
    const a = TailscaleFdEndpoint(fd: 1, local: local, bindingId: 1);
    const b = TailscaleFdEndpoint(fd: 1, local: local, bindingId: 2);
    const c = TailscaleFdEndpoint(fd: 1, local: local, bindingId: 1);
    const tcp = TailscaleFdEndpoint(fd: 1, local: local);

    expect(a, isNot(b));
    expect(a, c);
    expect(a.hashCode, c.hashCode);
    expect(tcp.bindingId, isNull);
    expect(a.toString(), contains('bindingId: 1'));
  });
}
