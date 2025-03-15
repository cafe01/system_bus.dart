import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'bus_logger.dart';
import 'bus_packet.dart';

/// A lightweight, URI-based message broker for Dart applications.
class SystemBus {
  /// Logger for this class
  final Logger _logger = BusLogger.get('bus');

  /// Internal port for receiving messages
  final ReceivePort _receivePort = ReceivePort();

  /// Map of registered listeners by host and port
  final Map<String, StreamController<BusPacket>> _listeners = {};

  /// Default timeout for request/response operations
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Creates a new SystemBus instance.
  SystemBus() {
    _receivePort.listen(_handleMessage);
    _logger.info('SystemBus initialized');
  }

  /// Returns the SendPort that peers can use to send messages to this bus.
  SendPort get sendPort => _receivePort.sendPort;

  /// Sends a request and waits for a response.
  ///
  /// This method creates a response channel, sends the request packet,
  /// and returns a Future that completes when the response is received.
  ///
  /// Parameters:
  /// - [verb]: The operation verb (any Enum value)
  /// - [uri]: The target resource URI
  /// - [payload]: Optional operation parameters
  /// - [timeout]: Optional timeout duration (defaults to 30 seconds)
  ///
  /// Returns a Future that completes with the response result or throws
  /// an exception if the request fails or times out.
  Future<dynamic> sendRequest({
    required Enum verb,
    required Uri uri,
    dynamic payload,
    Duration? timeout,
  }) async {
    final responsePort = ReceivePort();
    final actualTimeout = timeout ?? defaultTimeout;

    _logger.fine('Sending request: ${verb.runtimeType}.${verb.name} $uri');

    try {
      // Create the request packet
      final packet = BusPacket(
        verb: verb,
        uri: uri,
        payload: payload is Map<String, dynamic>
            ? payload
            : payload != null
                ? {'data': payload}
                : null,
        responsePort: responsePort.sendPort,
      );

      BusLogger.tracePacket(_logger, 'SENDING', packet);

      // Send the packet
      _receivePort.sendPort.send(packet);

      // Wait for response with timeout
      _logger
          .fine('Waiting for response (timeout: ${actualTimeout.inSeconds}s)');

      final response = await responsePort.first.timeout(
        actualTimeout,
        onTimeout: () {
          _logger.warning(
              'Request timed out after ${actualTimeout.inSeconds}s: ${verb.name} $uri');
          throw TimeoutException('Request timed out', actualTimeout);
        },
      );

      BusLogger.tracePacket(_logger, 'RECEIVED', response, detail: 'Response');

      // Validate response
      if (response is! BusPacket || !response.isResponse) {
        _logger.warning('Received invalid response packet');
        throw Exception('Invalid response format');
      }

      // Handle response
      if (response.success) {
        _logger.fine('Request succeeded');
        return response.result;
      } else {
        final errorMsg = response.errorMessage ?? 'Operation failed';
        _logger.warning('Request failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      if (e is! TimeoutException) {
        _logger.severe('Error during request', e, stackTrace);
      }
      rethrow;
    } finally {
      responsePort.close();
    }
  }

  /// Sends a response to a request packet.
  ///
  /// This method validates that the request packet has a responsePort,
  /// creates a response packet, and sends it back to the requester.
  ///
  /// Parameters:
  /// - [requestPacket]: The original request packet
  /// - [result]: The result data to send back
  /// - [success]: Whether the operation was successful (defaults to true)
  /// - [errorMessage]: Optional error message for failed operations
  ///
  /// Throws an exception if the request packet doesn't have a responsePort.
  void sendResponse(
    BusPacket requestPacket,
    dynamic result, {
    bool success = true,
    String? errorMessage,
  }) {
    if (requestPacket.responsePort == null) {
      _logger.warning('Cannot send response: request has no responsePort');
      throw ArgumentError('Request packet has no responsePort');
    }

    final response = BusPacket.response(
      request: requestPacket,
      success: success,
      result: result,
      errorMessage: errorMessage,
    );

    BusLogger.tracePacket(_logger, 'SENDING', response, detail: 'Response');
    requestPacket.responsePort!.send(response);
    _logger.fine('Response sent: ${success ? 'success' : 'failure'}');
  }

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
    if (message is! BusPacket) {
      _logger.warning('Invalid message format: $message');
      return;
    }

    try {
      final packet = message;
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
