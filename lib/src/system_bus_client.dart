import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'bus_logger.dart';
import 'bus_packet.dart';
import 'http_verb.dart';

/// Custom exception class for bus errors
class BusException implements Exception {
  BusException(this.message, this.verb, this.uri);
  final String message;
  final Enum verb;
  final Uri uri;

  @override
  String toString() =>
      'BusException: $message (${verb.runtimeType}.${verb.name} $uri)';
}

/// Abstract base class for SystemBus clients
abstract class SystemBusClient {
  /// Creates a SystemBus client
  SystemBusClient(
    this._busPort, {
    Duration defaultTimeout = const Duration(seconds: 30),
  }) : _defaultTimeout = defaultTimeout {
    logger.info(
      'SystemBusClient initialized with default timeout of ${defaultTimeout.inSeconds}s',
    );
  }

  /// Logger for this class
  Logger get logger => _logger;
  final Logger _logger = BusLogger.get('client');

  final SendPort _busPort;
  final Duration _defaultTimeout;

  /// Sends a request and waits for a response
  Future<dynamic> send({
    required Enum verb,
    required Uri uri,
    dynamic payload,
    Duration? timeout,
  }) async {
    final responsePort = ReceivePort();
    final actualTimeout = timeout ?? _defaultTimeout;

    logger.fine('Sending ${verb.runtimeType}.${verb.name} request to $uri');
    if (payload != null) {
      logger.fine('Request payload: $payload');
    }

    try {
      // Create and send the packet
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

      BusLogger.tracePacket(logger, 'SENDING', packet.toMap());
      _busPort.send(packet.toMap());

      // Wait for response with timeout
      logger
          .fine('Waiting for response (timeout: ${actualTimeout.inSeconds}s)');
      final response = await responsePort.first.timeout(
        actualTimeout,
        onTimeout: () {
          logger.warning(
            'Request timed out after ${actualTimeout.inSeconds}s: ${verb.name} $uri',
          );
          throw TimeoutException('Request timed out', actualTimeout);
        },
      );

      BusLogger.tracePacket(logger, 'RECEIVED', response, detail: 'Response');

      // The response is already a properly formatted packet
      if (response['isResponse'] != true) {
        logger.warning('Received non-response packet');
        throw BusException('Received non-response packet', verb, uri);
      }

      if (response['success'] == true) {
        logger.fine('Request succeeded');
        return response['result'];
      } else {
        final errorMsg =
            (response['errorMessage'] ?? 'Operation failed').toString();
        logger.warning('Request failed: $errorMsg');
        throw BusException(errorMsg, verb, uri);
      }
    } catch (e, stackTrace) {
      if (e is! TimeoutException) {
        logger.severe('Error during request', e, stackTrace);
      }
      rethrow;
    } finally {
      responsePort.close();
    }
  }
}

/// HTTP-specific client implementation
class HttpSystemBusClient extends SystemBusClient {
  final Logger _httpLogger = BusLogger.get('http_client');

  @override
  Logger get logger => _httpLogger;

  HttpSystemBusClient(
    SendPort busPort, {
    Duration defaultTimeout = const Duration(seconds: 30),
  }) : super(busPort, defaultTimeout: defaultTimeout) {
    logger.info('HttpSystemBusClient initialized');
  }

  Future<dynamic> get(Uri uri, [dynamic payload]) {
    logger.fine('GET $uri');
    return send(verb: HttpVerb.get, uri: uri, payload: payload);
  }

  Future<dynamic> post(Uri uri, dynamic payload) {
    logger.fine('POST $uri');
    return send(verb: HttpVerb.post, uri: uri, payload: payload);
  }

  Future<dynamic> put(Uri uri, dynamic payload) {
    logger.fine('PUT $uri');
    return send(verb: HttpVerb.put, uri: uri, payload: payload);
  }

  Future<dynamic> delete(Uri uri, [dynamic payload]) {
    logger.fine('DELETE $uri');
    return send(verb: HttpVerb.delete, uri: uri, payload: payload);
  }

  Future<dynamic> patch(Uri uri, dynamic payload) {
    logger.fine('PATCH $uri');
    return send(verb: HttpVerb.patch, uri: uri, payload: payload);
  }

  Future<dynamic> options(Uri uri, [dynamic payload]) {
    logger.fine('OPTIONS $uri');
    return send(verb: HttpVerb.options, uri: uri, payload: payload);
  }
}
