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

    test('BusPacket serialization and deserialization works correctly', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final payload = {'key': 'value'};

      final packet = BusPacket(
        verb: HttpVerb.post,
        uri: uri,
        payload: payload,
      );

      final map = packet.toMap();
      final deserializedPacket = BusPacket.fromMap(map, HttpVerb.values);

      expect(deserializedPacket.version, equals(packet.version));
      expect(deserializedPacket.verb, equals(packet.verb));
      expect(deserializedPacket.uri.toString(), equals(packet.uri.toString()));
      expect(deserializedPacket.payload, equals(packet.payload));
      expect(deserializedPacket.isResponse, equals(packet.isResponse));
      expect(deserializedPacket.success, equals(packet.success));
    });

    test('BusPacket response serialization and deserialization works correctly',
        () {
      final uri = Uri.parse('bus://test.host:123/path');
      final request = BusPacket(
        verb: HttpVerb.get,
        uri: uri,
      );

      final response = BusPacket.response(
        request: request,
        success: true,
        result: {'status': 'ok'},
      );

      final map = response.toMap();
      final deserializedResponse = BusPacket.fromMap(map, HttpVerb.values);

      expect(deserializedResponse.version, equals(response.version));
      expect(deserializedResponse.verb, equals(response.verb));
      expect(
          deserializedResponse.uri.toString(), equals(response.uri.toString()));
      expect(deserializedResponse.isResponse, isTrue);
      expect(deserializedResponse.success, isTrue);
      expect(deserializedResponse.result, equals({'status': 'ok'}));
    });

    test('Custom enum verbs are supported', () {
      final uri = Uri.parse('bus://custom.service:123/resource');
      final packet = BusPacket(
        verb: CustomVerb.action2,
        uri: uri,
        payload: {'custom': 'data'},
      );

      final map = packet.toMap();
      final deserializedPacket =
          BusPacket.fromMap(map, [...HttpVerb.values, ...CustomVerb.values]);

      expect(deserializedPacket.verb, equals(CustomVerb.action2));
      expect(deserializedPacket.uri.toString(), equals(uri.toString()));
      expect(deserializedPacket.payload, equals({'custom': 'data'}));
    });

    test('Throws error when deserializing unknown verb', () {
      final uri = Uri.parse('bus://test.host:123/path');
      final packet = BusPacket(
        verb: UnknownVerb.unknown,
        uri: uri,
      );

      final map = packet.toMap();

      expect(
        () => BusPacket.fromMap(map, HttpVerb.values),
        throwsArgumentError,
      );
    });
  });
}

// Define a custom enums
enum CustomVerb { action1, action2, action3 }

enum UnknownVerb { unknown }
