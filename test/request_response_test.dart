import 'dart:async';

import 'package:system_bus/system_bus.dart';
import 'package:test/test.dart';

void main() {
  group('Request/Response Tests', () {
    late SystemBus bus;

    setUp(() {
      bus = SystemBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('sendRequest and sendResponse work for successful operations',
        () async {
      // Set up a service that responds to requests
      final stream = bus.bindListener('test.service', 1);
      stream.listen((packet) {
        if (packet.verb == HttpVerb.get && packet.uri.path == '/resource') {
          bus.sendResponse(packet, {'status': 'success', 'data': 'test-data'});
        }
      });

      // Send a request and wait for the response
      final result = await bus.sendRequest(
        verb: HttpVerb.get,
        uri: Uri.parse('bus://test.service:1/resource'),
      );

      // Verify the response
      expect(result, isA<Map>());
      expect(result['status'], equals('success'));
      expect(result['data'], equals('test-data'));
    });

    test('sendRequest handles error responses correctly', () async {
      // Set up a service that responds with an error
      final stream = bus.bindListener('error.service', 1);
      stream.listen((packet) {
        if (packet.verb == HttpVerb.get && packet.uri.path == '/error') {
          bus.sendResponse(
            packet,
            null,
            success: false,
            errorMessage: 'Resource not found',
          );
        }
      });

      // Send a request and expect an exception
      expect(
        () => bus.sendRequest(
          verb: HttpVerb.get,
          uri: Uri.parse('bus://error.service:1/error'),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Resource not found'),
        )),
      );
    });

    test('sendRequest times out when no response is received', () async {
      // Set up a service that never responds
      final stream = bus.bindListener('timeout.service', 1);
      // Intentionally not responding to requests

      // Send a request with a short timeout
      expect(
        () => bus.sendRequest(
          verb: HttpVerb.get,
          uri: Uri.parse('bus://timeout.service:1/timeout'),
          timeout: Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('sendResponse throws when request has no responsePort', () {
      // Create a packet without a responsePort
      final packet = BusPacket(
        verb: HttpVerb.get,
        uri: Uri.parse('bus://test.service:1/resource'),
      );

      // Attempt to send a response
      expect(
        () => bus.sendResponse(packet, {'status': 'success'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sendRequest supports custom verb enums', () async {
      // Set up a service that responds to custom verbs
      final stream = bus.bindListener('custom.service', 1);
      stream.listen((packet) {
        if (packet.verb == CustomVerb.action && packet.uri.path == '/custom') {
          bus.sendResponse(packet, {'custom': true, 'action': 'performed'});
        }
      });

      // Send a request with a custom verb
      final result = await bus.sendRequest(
        verb: CustomVerb.action,
        uri: Uri.parse('bus://custom.service:1/custom'),
      );

      // Verify the response
      expect(result, isA<Map>());
      expect(result['custom'], isTrue);
      expect(result['action'], equals('performed'));
    });

    test('sendRequest handles payload conversion correctly', () async {
      // Set up a service that echoes the payload
      final stream = bus.bindListener('echo.service', 1);
      stream.listen((packet) {
        bus.sendResponse(packet, {'echo': packet.payload});
      });

      // Test with Map payload
      var result = await bus.sendRequest(
        verb: HttpVerb.post,
        uri: Uri.parse('bus://echo.service:1/echo'),
        payload: {'test': 'value', 'number': 42},
      );
      expect(result['echo'], equals({'test': 'value', 'number': 42}));

      // Test with non-Map payload
      result = await bus.sendRequest(
        verb: HttpVerb.post,
        uri: Uri.parse('bus://echo.service:1/echo'),
        payload: 'string-payload',
      );
      expect(result['echo'], equals({'data': 'string-payload'}));

      // Test with null payload
      result = await bus.sendRequest(
        verb: HttpVerb.post,
        uri: Uri.parse('bus://echo.service:1/echo'),
      );
      expect(result['echo'], isNull);
    });
  });
}

// Define a custom verb for testing
enum CustomVerb { action, query, update }
