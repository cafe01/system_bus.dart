# system_bus

A lightweight, URI-based message broker for Dart applications that enables structured communication between peers.

## Overview

SystemBus provides a clean, flexible way to route messages between different components of your application. It uses a URI-based addressing scheme similar to HTTP, making it intuitive and familiar to developers.

Each SystemBus instance acts as a scope for a group of peers, providing message routing without any knowledge of the peers themselves. This peer-agnostic approach makes it suitable for various communication scenarios.

### Design Philosophy

SystemBus is designed to be both peer and protocol agnostic. The bus itself is essentially a packet router that only cares about the `host` and `port` components of the URI for routing messages to the correct listeners. This design allows for:

1. **Custom Protocol Creation**: Create domain-specific protocols by defining custom verb enums and URI patterns
2. **Flexible Command Structure**: Each "command" is simply a combination of `VERB + URI + PAYLOAD`
3. **Protocol Independence**: The bus doesn't enforce any specific protocol semantics beyond basic routing

This approach means you can model any kind of communication pattern or domain-specific protocol on top of the basic routing infrastructure, from REST-like APIs to custom device control protocols.

## Features

- **URI-based addressing**: Route messages using standard URI format (`scheme://host:port/path?query`)
- **Protocol-agnostic design**: Define custom verbs and semantics for your specific use case
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
  
  // Get the send port to share with clients
  final sendPort = bus.sendPort;
  
  // Pass sendPort to clients that need to communicate with this bus
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
      packet.responsePort!.send(response);
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
  
  busSendPort.send(packet);
  
  // Listen for the response
  responsePort.listen((response) {
    // The response is a BusPacket
    print('Got response: ${response.result}');
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

### Using Request/Response Methods

SystemBus provides standardized methods for request/response communication:

```dart
// Client side: Send a request and await response
try {
  final result = await bus.sendRequest(
    verb: HttpVerb.get,
    uri: Uri.parse('bus://device.type:1/status'),
    payload: {'detail': true},
    timeout: Duration(seconds: 10), // Optional timeout
  );
  print('Got result: $result');
} catch (e) {
  print('Request failed: $e');
}

// Service side: Handle requests and send responses
final deviceStream = bus.bindListener('device.type', 1);
deviceStream.listen((packet) {
  if (packet.verb == HttpVerb.get && packet.uri.path == '/status') {
    try {
      // Process the request
      final status = getDeviceStatus();
      
      // Send a successful response
      bus.sendResponse(packet, {
        'status': 'online',
        'battery': 85,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Send an error response
      bus.sendResponse(
        packet,
        null,
        success: false,
        errorMessage: 'Failed to get device status: $e',
      );
    }
  }
});
```

Benefits of using these methods:
- Standardized error handling
- Built-in timeout management
- Automatic validation of response channels
- Clear, expressive API for request/response patterns

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

// Define verbs for CPU management
enum CpuVerb {
  throttle,
  boost,
  monitor,
  sleep,
}

// Define verbs for CRUD operations
enum CrudVerb {
  create,
  read,
  update,
  delete,
  list,
  search,
}

// Define verbs for Git operations
enum GitVerb {
  clone,
  pull,
  push,
  commit,
  checkout,
  merge,
}

// Define verbs for LLM operations
enum LlmVerb {
  generate,
  embed,
  tokenize,
  classify,
  summarize,
}

// Create a bus that supports multiple verb types
final bus = SystemBus(supportedVerbs: [
  ...HttpVerb.values,
  ...DeviceVerb.values,
  ...CpuVerb.values,
  // Add other verb enums as needed
]);

// Send a message with a custom verb
final packet = BusPacket(
  verb: DeviceVerb.configure,
  uri: Uri.parse('bus://device.manager:1/thermostat'),
  payload: {'temperature': 72, 'mode': 'auto'},
);

busSendPort.send(packet);
```

### Creating Custom Protocols

Creating a custom protocol with SystemBus is straightforward:

1. **Define a verb enum** that represents the operations in your domain
2. **Document URI patterns** that your protocol will use (paths, query parameters, etc.)
3. **Define payload structures** for each verb+URI combination
4. **Implement handlers** that bind to the appropriate host:port and process the commands

For example, a simple device control protocol might look like:

```dart
// 1. Define verbs
enum DeviceVerb { power, setMode, getStatus }

// 2. Document URI patterns
// bus://device.type:id/[device-name]
// Examples:
// - bus://thermostat:1/living-room
// - bus://light:2/kitchen

// 3. Define payload structures (in documentation or code)
// DeviceVerb.power: { "state": "on"|"off" }
// DeviceVerb.setMode: { "mode": string, ...mode-specific-params }
// DeviceVerb.getStatus: {} (empty payload)

// 4. Implement handler
void setupDeviceHandler(SystemBus bus, String deviceType, int id) {
  final stream = bus.bindListener(deviceType, id);
  
  stream.listen((packet) {
    if (packet.verb == DeviceVerb.power) {
      final state = packet.payload?['state'];
      // Handle power command...
    } else if (packet.verb == DeviceVerb.getStatus) {
      // Return device status...
      if (packet.responsePort != null) {
        final response = BusPacket.response(
          request: packet,
          success: true,
          result: {'power': 'on', 'mode': 'heating', 'temperature': 72},
        );
        packet.responsePort!.send(response);
      }
    }
    // Handle other verbs...
  });
}
```

This approach allows you to create clean, domain-specific APIs while leveraging the routing and message passing infrastructure of SystemBus.

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

## Roadmap

SystemBus follows a progressive release schedule, with each minor version focusing on key features:

- **0.4.0**: Standardized request/response pattern for simpler communication
- **0.5.0**: Peer discovery mechanism for automatic service detection
- **0.6.0**: Path-based routing with support for route parameters
- **0.7.0**: Pub/Sub pattern for topic-based event distribution
- **0.8.0**: Message filtering and validation capabilities
- **0.9.0**: Performance optimizations for high-frequency communications
- **1.0.0**: Stable API with comprehensive documentation

This roadmap serves as a guide and may be adjusted based on user feedback and evolving requirements.

## License

This package is available under the MIT License.

