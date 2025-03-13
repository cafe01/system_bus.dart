import 'dart:isolate';

/// The core message format for SystemBus communications.
class BusPacket {
  /// Protocol version (currently hardcoded to 1)
  final int version;

  /// The verb/operation to perform (can be any Enum type)
  final Enum verb;

  /// Target resource URI
  final Uri uri;

  /// Operation parameters
  final Map<String, dynamic>? payload;

  /// Direct response channel
  final SendPort? responsePort;

  /// Whether this packet is a response to another packet
  final bool isResponse;

  /// Whether the operation was successful (for responses)
  final bool success;

  /// Result data (for responses)
  final dynamic result;

  /// Error message (for failed responses)
  final String? errorMessage;

  /// Creates a new request packet.
  BusPacket({
    required this.verb,
    required this.uri,
    this.payload,
    this.responsePort,
  })  : version = 1,
        isResponse = false,
        success = false,
        result = null,
        errorMessage = null;

  /// Creates a response packet.
  BusPacket.response({
    required BusPacket request,
    required this.success,
    this.result,
    this.errorMessage,
  })  : version = 1,
        verb = request.verb,
        uri = request.uri,
        payload = null,
        responsePort = null,
        isResponse = true;

  /// Converts this packet to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'verbType': verb.runtimeType.toString(),
      'verbValue': verb.name,
      'uri': uri.toString(),
      if (payload != null) 'payload': payload,
      if (responsePort != null) 'responsePort': responsePort,
      'isResponse': isResponse,
      'success': success,
      if (result != null) 'result': result,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Creates a packet from a serialized map.
  ///
  /// [enumValues] should contain all possible enum values that could be used
  /// in the packets being deserialized.
  static BusPacket fromMap(
    Map<String, dynamic> map,
    List<Enum> enumValues,
  ) {
    // Find the enum value by name
    final verbName = map['verbValue'];
    final verbType = map['verbType'];

    final verb = enumValues.firstWhere(
      (e) => e.name == verbName && e.runtimeType.toString() == verbType,
      orElse: () =>
          throw ArgumentError('Unknown verb: $verbName of type $verbType'),
    );

    if (map['isResponse'] == true) {
      return BusPacket.response(
        request: BusPacket(
          verb: verb,
          uri: Uri.parse(map['uri']),
        ),
        success: map['success'],
        result: map['result'],
        errorMessage: map['errorMessage'],
      );
    } else {
      return BusPacket(
        verb: verb,
        uri: Uri.parse(map['uri']),
        payload: map['payload'],
        responsePort: map['responsePort'],
      );
    }
  }
}
