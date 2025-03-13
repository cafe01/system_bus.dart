import 'dart:async';
import 'dart:isolate';

import 'package:system_bus/system_bus.dart';
import 'package:test/test.dart';

void main() {
  group('SystemBus Tests', () {
    late SystemBus bus;

    setUp(() {
      bus = SystemBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('SystemBus provides a valid SendPort', () {
      expect(bus.sendPort, isA<SendPort>());
    });

    test('bindListener returns a Stream<BusPacket>', () {
      final stream = bus.bindListener('test.host', 123);
      expect(stream, isA<Stream<BusPacket>>());
    });

    test('Messages are routed to the correct listener', () async {
      final completer = Completer<BusPacket>();

      // Bind a listener
      final stream = bus.bindListener('test.host', 123);
      final subscription = stream.listen((packet) {
        completer.complete(packet);
      });

      // Send a message to the bus
      final packet = BusPacket(
        verb: HttpVerb.get,
        uri: Uri.parse('bus://test.host:123/path'),
        payload: {'key': 'value'},
      );

      bus.sendPort.send(packet);

      // Wait for the message to be received
      final receivedPacket = await completer.future;

      expect(receivedPacket.verb, equals(HttpVerb.get));
      expect(receivedPacket.uri.toString(), equals('bus://test.host:123/path'));
      expect(receivedPacket.payload, equals({'key': 'value'}));

      await subscription.cancel();
    });

    test('Messages are not routed to incorrect listeners', () async {
      final completer = Completer<bool>();

      // Bind a listener to a different host/port
      final stream = bus.bindListener('other.host', 456);

      bool receivedMessage = false;
      final subscription = stream.listen((_) {
        receivedMessage = true;
      });

      // Send a message to a different host/port
      final packet = BusPacket(
        verb: HttpVerb.get,
        uri: Uri.parse('bus://test.host:123/path'),
        payload: {'key': 'value'},
      );

      bus.sendPort.send(packet);

      // Wait a bit to ensure the message is processed
      await Future.delayed(Duration(milliseconds: 100));
      completer.complete(receivedMessage);

      expect(await completer.future, isFalse);
      await subscription.cancel();
    });

    test('bindListener is case-insensitive for host names', () async {
      final completer = Completer<BusPacket>();

      // Bind listener with mixed case
      final stream = bus.bindListener('Test.Host', 123);
      final subscription = stream.listen((packet) {
        completer.complete(packet);
      });

      // Send message with different case
      final packet = BusPacket(
        verb: HttpVerb.get,
        uri: Uri.parse('bus://test.host:123/path'),
        payload: {'key': 'value'},
      );

      bus.sendPort.send(packet);

      final receivedPacket = await completer.future;
      expect(receivedPacket.uri.host, equals('test.host'));

      await subscription.cancel();
    });

    test('SystemBus supports custom verb enums', () async {
      // Create a bus with custom verbs
      final customBus =
          SystemBus(supportedVerbs: [...HttpVerb.values, ...CustomVerb.values]);

      final completer = Completer<BusPacket>();

      // Bind a listener
      final stream = customBus.bindListener('custom.service', 123);
      final subscription = stream.listen((packet) {
        completer.complete(packet);
      });

      // Send a message with a custom verb
      final packet = BusPacket(
        verb: CustomVerb.action2,
        uri: Uri.parse('bus://custom.service:123/resource'),
        payload: {'custom': 'data'},
      );

      customBus.sendPort.send(packet);

      // Wait for the message to be received
      final receivedPacket = await completer.future;

      expect(receivedPacket.verb, equals(CustomVerb.action2));
      expect(receivedPacket.uri.toString(),
          equals('bus://custom.service:123/resource'));
      expect(receivedPacket.payload, equals({'custom': 'data'}));

      await subscription.cancel();
      customBus.dispose();
    });
  });
}

// Define a custom enum
enum CustomVerb { action1, action2, action3 }
