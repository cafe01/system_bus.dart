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
        verb: HttpVerb.get,
        uri: uri,
        payload: payload,
        responsePort: responsePort,
      );

      expect(packet.version, equals(1));
      expect(packet.verb, equals(HttpVerb.get));
      expect(packet.uri, equals(uri));
      expect(packet.payload, equals(payload));
      expect(packet.responsePort, equals(responsePort));
      expect(packet.isResponse, isFalse);
      expect(packet.success, isFalse);
      expect(packet.result, isNull);
      expect(packet.errorMessage, isNull);
    });

    test('BusPacket.response constructor sets all fields correctly', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final request = BusPacket(
        verb: HttpVerb.get,
        uri: uri,
      );

      final response = BusPacket.response(
        request: request,
        success: true,
        result: {'status': 'ok'},
        errorMessage: null,
      );

      expect(response.version, equals(1));
      expect(response.verb, equals(HttpVerb.get));
      expect(response.uri, equals(uri));
      expect(response.payload, isNull);
      expect(response.responsePort, isNull);
      expect(response.isResponse, isTrue);
      expect(response.success, isTrue);
      expect(response.result, equals({'status': 'ok'}));
      expect(response.errorMessage, isNull);
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

// Define a custom enums
enum CustomVerb { action1, action2, action3 }
