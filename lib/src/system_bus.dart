import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'bus_logger.dart';
import 'bus_packet.dart';
import 'http_verb.dart';

/// A lightweight, URI-based message broker for Dart applications.
class SystemBus {
  /// Logger for this class
  final Logger _logger = BusLogger.get('bus');

  /// Internal port for receiving messages
  final ReceivePort _receivePort = ReceivePort();

  /// Map of registered listeners by host and port
  final Map<String, StreamController<BusPacket>> _listeners = {};

  /// List of all supported enum values for deserialization
  final List<Enum> _supportedVerbs;

  /// Creates a new SystemBus instance.
  ///
  /// [supportedVerbs] is the list of all enum values that this bus should
  /// support for deserialization. If not provided, defaults to HttpVerb values.
  SystemBus({List<Enum>? supportedVerbs})
      : _supportedVerbs = supportedVerbs ?? HttpVerb.values {
    _receivePort.listen(_handleMessage);
    _logger.info(
        'SystemBus initialized with ${_supportedVerbs.length} supported verbs');
  }

  /// Returns the SendPort that peers can use to send messages to this bus.
  SendPort get sendPort => _receivePort.sendPort;

  /// Binds a listener to a specific host and port.
  ///
  /// Returns a Stream of BusPacket objects that match the specified host and port.
  /// Host matching is case-insensitive.
  Stream<BusPacket> bindListener(String host, int port) {
    // Convert host to lowercase for case-insensitive matching
    final normalizedHost = host.toLowerCase();
    final key = '$normalizedHost:$port';

    if (!_listeners.containsKey(key)) {
      _listeners[key] = StreamController<BusPacket>.broadcast();
      _logger.info('Listener bound to $key');
    } else {
      _logger.fine('Using existing listener for $key');
    }

    return _listeners[key]!.stream;
  }

  /// Handles incoming messages and routes them to the appropriate listeners.
  void _handleMessage(dynamic message) {
    if (message is! Map<String, dynamic>) {
      _logger.warning('Invalid message format: $message');
      return;
    }

    try {
      final packet = BusPacket.fromMap(message, _supportedVerbs);
      final uri = packet.uri;

      BusLogger.tracePacket(_logger, 'RECEIVED', packet);

      if (uri.scheme != 'bus') {
        _logger.warning('Invalid URI scheme: ${uri.scheme}');
        return;
      }

      // Normalize host to lowercase for case-insensitive matching
      final normalizedHost = uri.host.toLowerCase();
      final key = '$normalizedHost:${uri.port}';

      if (_listeners.containsKey(key)) {
        _logger
            .fine('Routing packet to $key: ${packet.verb.name} ${packet.uri}');
        _listeners[key]!.add(packet);
      } else {
        _logger.warning('No listener found for $key');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error processing message', e, stackTrace);
    }
  }

  /// Closes the bus and all associated listeners.
  void dispose() {
    _logger.info('Disposing SystemBus');
    _receivePort.close();
    for (final controller in _listeners.values) {
      controller.close();
    }
    _listeners.clear();
  }
}
