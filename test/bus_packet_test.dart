import 'dart:isolate';

import 'package:system_bus/system_bus.dart';
import 'package:test/test.dart';

void main() {
  group('BusPacket Tests', () {
    test('BusPacket constructor sets all fields correctly', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final payload = {'key': 'value'};
      final responsePort = ReceivePort().sendPort;

      final packet = BusPacket(
        verb: CustomVerb.action1,
        uri: uri,
        payload: payload,
        responsePort: responsePort,
      );

      expect(packet.version, equals(1));
      expect(packet.verb, equals(CustomVerb.action1));
      expect(packet.uri, equals(uri));
      expect(packet.payload, equals(payload));
      expect(packet.responsePort, equals(responsePort));
      expect(packet.isResponse, isFalse);
      expect(packet.success, isFalse);
      expect(packet.errorCode, isNull);
      expect(packet.errorMessage, isNull);
    });

    test('BusPacket.response constructor sets all fields correctly', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final request = BusPacket(
        verb: CustomVerb.action1,
        uri: uri,
      );

      final response = BusPacket.response(
        request: request,
        success: true,
        payload: {'status': 'ok'},
        errorCode: null,
        errorMessage: null,
      );

      expect(response.version, equals(1));
      expect(response.verb, equals(CustomVerb.action1));
      expect(response.uri, equals(uri));
      expect(response.payload, equals({'status': 'ok'}));
      expect(response.responsePort, isNull);
      expect(response.isResponse, isTrue);
      expect(response.success, isTrue);
      expect(response.errorCode, isNull);
      expect(response.errorMessage, isNull);
    });

    test('Error response includes errorCode and errorMessage', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final request = BusPacket(
        verb: CustomVerb.action1,
        uri: uri,
      );

      final response = BusPacket.response(
        request: request,
        success: false,
        errorCode: 'NOT_FOUND',
        errorMessage: 'Resource not found',
      );

      expect(response.success, isFalse);
      expect(response.errorCode, equals('NOT_FOUND'));
      expect(response.errorMessage, equals('Resource not found'));
    });

    test('Custom enum verbs are supported', () {
      final uri = Uri.parse('bus://custom.service:123/resource');
      final packet = BusPacket(
        verb: CustomVerb.action2,
        uri: uri,
        payload: {'custom': 'data'},
      );

      expect(packet.verb, equals(CustomVerb.action2));
      expect(packet.uri.toString(), equals(uri.toString()));
      expect(packet.payload, equals({'custom': 'data'}));
    });
  });
}

// Define a custom enum
enum CustomVerb { action1, action2, action3 }
