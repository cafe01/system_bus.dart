import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:system_bus/src/bus_logger.dart';
import 'package:system_bus/src/system_bus_client.dart';
import 'package:system_bus/system_bus.dart';
import 'package:test/test.dart';

// Custom verb for testing
enum TestVerb { custom, action }

void main() {
  // Initialize logging with a lower level for tests
  BusLogger.init(level: Level.FINE);

  group('SystemBusClient Tests', () {
    late SystemBus bus;
    late SendPort busSendPort;
    late TestClient client;

    setUp(() {
      bus = SystemBus();
      busSendPort = bus.sendPort;
      client = TestClient(busSendPort);

      // Set up a listener for the test service
      final stream = bus.bindListener('test.service', 123);
      stream.listen((packet) {
        // Echo back the request as a response
        if (packet.responsePort != null) {
          final response = BusPacket.response(
            request: packet,
            success: true,
            result: {'echo': packet.payload, 'verb': packet.verb.name},
          );
          packet.responsePort!.send(response);
        }
      });

      // Set up a listener that simulates errors
      final errorStream = bus.bindListener('error.service', 456);
      errorStream.listen((packet) {
        if (packet.responsePort != null) {
          final response = BusPacket.response(
            request: packet,
            success: false,
            errorMessage: 'Simulated error',
          );
          packet.responsePort!.send(response);
        }
      });

      // Set up a listener that never responds (for timeout testing)
      final timeoutStream = bus.bindListener('timeout.service', 789);
      timeoutStream.listen((_) {
        // Intentionally do nothing to cause a timeout
      });
    });

    tearDown(() {
      bus.dispose();
    });

    test('Client can send requests and receive responses', () async {
      final result = await client.send(
        verb: TestVerb.custom,
        uri: Uri.parse('bus://test.service:123/resource'),
        payload: {'test': 'data'},
      );

      expect(result, isA<Map>());
      expect(result['echo'], {'test': 'data'});
      expect(result['verb'], 'custom');
    });

    test('Client handles error responses correctly', () async {
      expect(
        () => client.send(
          verb: TestVerb.custom,
          uri: Uri.parse('bus://error.service:456/resource'),
        ),
        throwsA(isA<BusException>()),
      );

      try {
        await client.send(
          verb: TestVerb.custom,
          uri: Uri.parse('bus://error.service:456/resource'),
        );
      } catch (e) {
        expect(e, isA<BusException>());
        expect((e as BusException).message, 'Simulated error');
        expect(e.verb, TestVerb.custom);
      }
    });

    test('Client handles timeouts correctly', () async {
      expect(
        () => client.send(
          verb: TestVerb.custom,
          uri: Uri.parse('bus://timeout.service:789/resource'),
          timeout: Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('HttpSystemBusClient Tests', () {
    late SystemBus bus;
    late SendPort busSendPort;
    late HttpSystemBusClient client;

    setUp(() {
      bus = SystemBus();
      busSendPort = bus.sendPort;
      client = HttpSystemBusClient(busSendPort);

      // Set up a listener for the API service
      final stream = bus.bindListener('api.service', 123);
      stream.listen((packet) {
        // Echo back the request as a response with the verb
        if (packet.responsePort != null) {
          final response = BusPacket.response(
            request: packet,
            success: true,
            result: {'method': packet.verb.name, 'path': packet.uri.path},
          );
          packet.responsePort!.send(response);
        }
      });
    });

    tearDown(() {
      bus.dispose();
    });

    test('HTTP verb methods work correctly', () async {
      final uri = Uri.parse('bus://api.service:123/users');

      // Test GET
      var result = await client.get(uri);
      expect(result['method'], 'get');
      expect(result['path'], '/users');

      // Test POST
      result = await client.post(uri, {'name': 'Test User'});
      expect(result['method'], 'post');

      // Test PUT
      result = await client.put(uri, {'id': 1, 'name': 'Updated User'});
      expect(result['method'], 'put');

      // Test DELETE
      result = await client.delete(uri);
      expect(result['method'], 'delete');

      // Test PATCH
      result = await client.patch(uri, {'status': 'active'});
      expect(result['method'], 'patch');

      // Test OPTIONS
      result = await client.options(uri);
      expect(result['method'], 'options');
    });
  });
}

// Test implementation of SystemBusClient
class TestClient extends SystemBusClient {
  TestClient(SendPort busPort) : super(busPort);
}
