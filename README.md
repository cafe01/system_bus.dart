# system_bus

A lightweight, URI-based message broker for Dart applications that enables structured communication between peers.

## Overview

SystemBus provides a clean, flexible way to route messages between different components of your application. It uses a URI-based addressing scheme similar to HTTP, making it intuitive and familiar to developers.

Each SystemBus instance acts as a scope for a group of peers, providing message routing without any knowledge of the peers themselves. This peer-agnostic approach makes it suitable for various communication scenarios.

## Features

- **URI-based addressing**: Route messages using standard URI format (`scheme://host:port/path?query`)
- **Stream-based API**: Bind listeners to specific URI patterns and receive messages as streams
- **Direct response channels**: Built-in support for request/response patterns
- **Lightweight**: Minimal dependencies and overhead
- **Peer-agnostic**: No assumptions about communication endpoints
- **Type-safe messaging**: Structured packet format with serialization support
- **Flexible verb system**: Support for custom protocol verbs beyond HTTP
- **Logging infrastructure**: Configurable logging with message tracing

## Installation

Add this package to your pubspec.yaml:

```yaml
dependencies:
  system_bus: ^0.1.0
```

## Basic Usage

### Creating a Bus

```dart
import 'package:system_bus/system_bus.dart';

void main() {
  // Create a bus instance
  final bus = SystemBus();
  
  // Get the send port to share with peers
  final sendPort = bus.sendPort;
  
  // Pass sendPort to peers as needed
}
```

### Binding Listeners

```dart
// Bind a listener for a specific host and port
Stream<BusPacket> deviceStream = bus.bindListener('device.type', 1);

// Listen for messages
deviceStream.listen((packet) {
  print('Received: ${packet.verb} ${packet.uri}');
  
  // Handle the message
  if (packet.verb == HttpVerb.get && packet.uri.path == '/status') {
    // Send a response if a response port was provided
    if (packet.responsePort != null) {
      final response = BusPacket.response(
        request: packet,
        success: true,
        result: {'status': 'online'},
      );
      packet.responsePort!.send(response.toMap());
    }
  }
});
```

### Sending Messages

```dart
// From a peer that has the bus sendPort
void sendMessage(SendPort busSendPort) {
  // Create a port to receive the response
  final responsePort = ReceivePort();
  
  // Create and send a message
  final packet = BusPacket(
    verb: HttpVerb.get,
    uri: Uri.parse('bus://device.type:1/status'),
    payload: {'detail': true},
    responsePort: responsePort.sendPort,
  );
  
  busSendPort.send(packet.toMap());
  
  // Listen for the response
  responsePort.listen((response) {
    // The response is already a Map, no need for BusPacket.fromMap
    print('Got response: ${response['result']}');
    responsePort.close();
  });
}
```

### Using SystemBusClient

For a more convenient API, you can use the `HttpSystemBusClient` which wraps the message-passing mechanics with a Future-based interface:

```dart
// Create an HTTP client with the bus send port
final client = HttpSystemBusClient(busSendPort);

// Simple GET request
try {
  final result = await client.get(Uri.parse('bus://device.type:1/status'));
  print('Status: $result');
} catch (e) {
  print('Error: $e');
}

// POST with payload
final createResult = await client.post(
  Uri.parse('bus://device.type:1/resource'),
  {'name': 'New Resource', 'priority': 'high'}
);

// Other verb methods
await client.put(uri, payload);
await client.delete(uri);
await client.patch(uri, payload);
await client.options(uri);
```

The client automatically:
- Creates the appropriate BusPacket with the correct verb
- Sets up a response channel
- Handles the response and error cases
- Returns a Future that completes with the result or error

This provides a more ergonomic API for common request/response patterns compared to manually creating packets and managing response ports.

### Custom Protocol Verbs

You can define your own verb enums for domain-specific protocols:

```dart
// Define custom verbs for device management
enum DeviceVerb {
  discover,
  register,
  configure,
  reboot,
}

// Create a bus that supports both HTTP and device verbs
final bus = SystemBus(supportedVerbs: [...HttpVerb.values, ...DeviceVerb.values]);

// Send a message with a custom verb
final packet = BusPacket(
  verb: DeviceVerb.configure,
  uri: Uri.parse('bus://device.manager:1/thermostat'),
  payload: {'temperature': 72, 'mode': 'auto'},
);

busSendPort.send(packet.toMap());
```

### Configuring Logging

The package includes a logging system built on the 'logging' package:

```dart
// Initialize logging with a specific level
BusLogger.init(level: Level.INFO, includeCallerInfo: true);

// Get a logger for a specific component
final logger = BusLogger.get('my_component');

// Log messages at different levels
logger.fine('Detailed debug information');
logger.info('Normal operation information');
logger.warning('Warning condition');
logger.severe('Error condition', error, stackTrace);
```

## Packet Structure

The `BusPacket` class is the core message format:

```dart
class BusPacket {
  final int version;             // Protocol version (currently 1)
  final Enum verb;               // Operation verb (can be any Enum)
  final Uri uri;                 // Target resource URI
  final Map<String, dynamic>? payload;  // Operation parameters
  final SendPort? responsePort;  // Direct response channel
  
  // For responses
  final bool isResponse;
  final bool success;
  final dynamic result;
  final String? errorMessage;
  
  // Constructors and helper methods...
}
```

## HttpVerb Enum

The standard HTTP verb enum is provided for RESTful-style communication:

```dart
enum HttpVerb {
  get,     // Retrieve a resource
  post,    // Create a resource
  put,     // Update a resource
  delete,  // Remove a resource
  patch,   // Partially update a resource
  options, // Retrieve communication options
  head,    // Check if a resource exists
}
```

## Future Enhancements

Currently, SystemBus supports the basic request/response pattern through the `bindListener` method. Future versions will include support for additional communication patterns:

- **Pub/Sub**: Publish/subscribe pattern for one-to-many communication
- **Signals**: Unidirectional event broadcasting
- **Channels**: Bi-directional communication streams between peers
- **Path-based routing**: Similar to HTTP routers with parameter extraction
- **Performance optimizations**: Message batching and efficient serialization

## License

This package is available under the MIT License.

