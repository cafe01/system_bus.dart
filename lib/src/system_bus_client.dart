import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'bus_logger.dart';
import 'bus_packet.dart';
import 'http_verb.dart';

/// Custom exception class for bus errors
class BusException implements Exception {
  final String message;
  final Enum verb;
  final Uri uri;

  BusException(this.message, this.verb, this.uri);

  @override
  String toString() =>
      'BusException: $message (${verb.runtimeType}.${verb.name} $uri)';
}

/// Abstract base class for SystemBus clients
abstract class SystemBusClient {
  /// Logger for this class
  final Logger _logger = BusLogger.get('client');

  final SendPort _busPort;
  final Duration _defaultTimeout;

  /// Creates a SystemBus client
  SystemBusClient(
    this._busPort, {
    Duration defaultTimeout = const Duration(seconds: 30),
  }) : _defaultTimeout = defaultTimeout {
    _logger.info(
        'SystemBusClient initialized with default timeout of ${defaultTimeout.inSeconds}s');
  }

  /// Sends a request and waits for a response
  Future<dynamic> send({
    required Enum verb,
    required Uri uri,
    dynamic payload,
    Duration? timeout,
  }) async {
    final responsePort = ReceivePort();
    final actualTimeout = timeout ?? _defaultTimeout;

    _logger.fine('Sending ${verb.runtimeType}.${verb.name} request to $uri');
    if (payload != null) {
      _logger.fine('Request payload: $payload');
    }

    try {
      // Create and send the packet
      final packet = BusPacket(
        verb: verb,
        uri: uri,
        payload: payload,
        responsePort: responsePort.sendPort,
      );

      BusLogger.tracePacket(_logger, 'SENDING', packet.toMap());
      _busPort.send(packet.toMap());

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

      // The response is already a properly formatted packet
      if (response['isResponse'] != true) {
        _logger.warning('Received non-response packet');
        throw BusException('Received non-response packet', verb, uri);
      }

      if (response['success'] == true) {
        _logger.fine('Request succeeded');
        return response['result'];
      } else {
        final errorMsg = response['errorMessage'] ?? 'Operation failed';
        _logger.warning('Request failed: $errorMsg');
        throw BusException(errorMsg, verb, uri);
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
}

/// HTTP-specific client implementation
class HttpSystemBusClient extends SystemBusClient {
  final Logger _logger = BusLogger.get('http_client');

  HttpSystemBusClient(SendPort busPort,
      {Duration defaultTimeout = const Duration(seconds: 30)})
      : super(busPort, defaultTimeout: defaultTimeout) {
    _logger.info('HttpSystemBusClient initialized');
  }

  Future<dynamic> get(Uri uri, [dynamic payload]) {
    _logger.fine('GET $uri');
    return send(verb: HttpVerb.get, uri: uri, payload: payload);
  }

  Future<dynamic> post(Uri uri, dynamic payload) {
    _logger.fine('POST $uri');
    return send(verb: HttpVerb.post, uri: uri, payload: payload);
  }

  Future<dynamic> put(Uri uri, dynamic payload) {
    _logger.fine('PUT $uri');
    return send(verb: HttpVerb.put, uri: uri, payload: payload);
  }

  Future<dynamic> delete(Uri uri, [dynamic payload]) {
    _logger.fine('DELETE $uri');
    return send(verb: HttpVerb.delete, uri: uri, payload: payload);
  }

  Future<dynamic> patch(Uri uri, dynamic payload) {
    _logger.fine('PATCH $uri');
    return send(verb: HttpVerb.patch, uri: uri, payload: payload);
  }

  Future<dynamic> options(Uri uri, [dynamic payload]) {
    _logger.fine('OPTIONS $uri');
    return send(verb: HttpVerb.options, uri: uri, payload: payload);
  }
}
