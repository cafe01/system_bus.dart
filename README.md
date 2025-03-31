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
- **Flexible verb system**: Support for custom protocol verbs
- **Logging infrastructure**: Configurable logging with message tracing

## Installation

Add this package to your pubspec.yaml:

```yaml
dependencies:
  system_bus: ^0.5.0
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
// Define your own protocol verbs
enum DeviceVerb { get, set, delete }

// Bind a listener for a specific host and port
Stream<BusPacket> deviceStream = bus.bindListener('device.type', 1);

// Listen for messages
deviceStream.listen((packet) {
  print('Received: ${packet.verb} ${packet.uri}');
  
  // Handle the message
  if (packet.verb == DeviceVerb.get && packet.uri.path == '/status') {
    // Send a response if a response port was provided
    if (packet.responsePort != null) {
      final response = BusPacket.response(
        request: packet,
        success: true,
        payload: {'status': 'online'},
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
  // Define your protocol verbs
  enum DeviceVerb { get, set, delete }
  
  // Create a port to receive the response
  final responsePort = ReceivePort();
  
  // Create and send a message
  final packet = BusPacket(
    verb: DeviceVerb.get,
    uri: Uri.parse('device://device.type:1/status'),
    payload: {'detail': true},
    responsePort: responsePort.sendPort,
  );
  
  busSendPort.send(packet);
  
  // Listen for the response
  responsePort.listen((response) {
    // The response is a BusPacket
    print('Got response: ${response.payload}');
    responsePort.close();
  });
}
```

### Using Request/Response Methods

SystemBus provides standardized methods for request/response communication:

```dart
// Define your protocol verbs
enum DeviceVerb { get, set, delete }

// Client side: Send a request and await response
try {
  final result = await bus.sendRequest(
    verb: DeviceVerb.get,
    uri: Uri.parse('device://device.type:1/status'),
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
  if (packet.verb == DeviceVerb.get && packet.uri.path == '/status') {
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
        errorCode: 'DEVICE_ERROR',
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

// Send a message with a custom verb
final packet = BusPacket(
  verb: DeviceVerb.configure,
  uri: Uri.parse('device://device.manager:1/thermostat'),
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
// device://device.type:id/[device-name]
// Examples:
// - device://thermostat:1/living-room
// - device://light:2/kitchen

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
          payload: {'power': 'on', 'mode': 'heating', 'temperature': 72},
        );
        packet.responsePort!.send(response);
      }
    }
    // Handle other verbs...
  });
}
```

This approach allows you to create clean, domain-specific APIs while leveraging the routing and message passing infrastructure of SystemBus.

## Protocol Implementation Guide

For more complex protocol implementations, we recommend using a client-dispatcher pattern that provides a clean separation of concerns. This section demonstrates how to implement a complete fictional SmartHome protocol following best practices.

### 1. Protocol Definition

Start by defining your protocol's core components - verbs, data structures, and error types:

```dart
/// SmartHome protocol verbs
enum SmartHomeVerb {
  power,      // Turn devices on/off
  set,        // Set a device property (brightness, temperature, etc.)
  get,        // Get a device property or status
  discover,   // Discover available devices
}

/// Light state information
class LightState {
  final bool isPowered;
  final int brightness;  // 0-100 percent
  
  LightState({required this.isPowered, required this.brightness});
  
  Map<String, dynamic> toJson() => {
    'isPowered': isPowered,
    'brightness': brightness,
  };
  
  factory LightState.fromJson(Map<String, dynamic> json) {
    return LightState(
      isPowered: json['isPowered'] as bool,
      brightness: json['brightness'] as int,
    );
  }
}

/// Exception for SmartHome-related errors
class SmartHomeException implements Exception {
  final String code;
  final String message;

  SmartHomeException(this.code, this.message);

  @override
  String toString() => 'SmartHomeException: [$code] $message';
}
```

### 2. Protocol Dispatcher

Create a dispatcher that handles messages on the firmware side:

```dart
/// Handler function types
typedef PowerHandler = Future<void> Function(dynamic device, String deviceId, bool state);
typedef SetBrightnessHandler = Future<LightState> Function(
    dynamic device, String lightId, int brightness);
typedef GetStatusHandler = Future<LightState> Function(dynamic device, String lightId);

/// Dispatcher for SmartHome protocol messages
class SmartHomeProtocolDispatcher {
  final PowerHandler _powerHandler;
  final SetBrightnessHandler _setBrightnessHandler;
  final GetStatusHandler _getStatusHandler;
  
  SmartHomeProtocolDispatcher({
    required PowerHandler powerHandler,
    required SetBrightnessHandler setBrightnessHandler,
    required GetStatusHandler getStatusHandler,
  }) : _powerHandler = powerHandler,
       _setBrightnessHandler = setBrightnessHandler,
       _getStatusHandler = getStatusHandler;
       
  /// Handles incoming bus packets
  Future<void> handlePacket(BusPacket packet, dynamic device) async {
    final verb = packet.verb as SmartHomeVerb;
    final uri = packet.uri;
    final params = uri.queryParameters;
    final responsePort = packet.responsePort;
    
    try {
      // Process the packet based on verb and path
      dynamic result;
      final deviceId = params['id'];
      
      if (deviceId == null) {
        throw SmartHomeException('MISSING_PARAMETER', 'Device ID is required');
      }
      
      switch (verb) {
        case SmartHomeVerb.power:
          final state = params['state'] == 'on';
          await _powerHandler(device, deviceId, state);
          result = {'success': true};
          break;
          
        case SmartHomeVerb.set:
          if (uri.path.contains('/brightness')) {
            final brightness = int.tryParse(params['value'] ?? '');
            if (brightness == null) {
              throw SmartHomeException('INVALID_PARAMETER', 'Brightness must be a number');
            }
            final state = await _setBrightnessHandler(device, deviceId, brightness);
            result = state.toJson();
          } else {
            throw SmartHomeException('INVALID_PATH', 'Unknown set operation path: ${uri.path}');
          }
          break;
          
        case SmartHomeVerb.get:
          if (uri.path.contains('/status')) {
            final state = await _getStatusHandler(device, deviceId);
            result = state.toJson();
          } else {
            throw SmartHomeException('INVALID_PATH', 'Unknown get operation path: ${uri.path}');
          }
          break;
          
        default:
          throw SmartHomeException('UNSUPPORTED_OPERATION', 'Verb not supported: ${verb.name}');
      }
      
      // Send success response
      if (responsePort != null) {
        final response = BusPacket.response(
          request: packet,
          success: true,
          payload: result,
        );
        responsePort.send(response);
      }
    } catch (e) {
      // Handle errors and send error response
      if (responsePort != null) {
        final errorCode = e is SmartHomeException ? e.code : 'INTERNAL_ERROR';
        final errorMessage = e is SmartHomeException ? e.message : e.toString();
        
        final response = BusPacket.response(
          request: packet,
          success: false,
          errorCode: errorCode,
          errorMessage: errorMessage,
        );
        responsePort.send(response);
      }
    }
  }
}
```

### 3. Protocol Client

Create a client that provides a clean, type-safe API for using the protocol:

```dart
/// Client for the SmartHome protocol
class SmartHomeClient {
  final SendPort _sendPort;
  final String _deviceHost;
  final int _devicePort;
  
  SmartHomeClient(this._sendPort, this._deviceHost, this._devicePort);
  
  /// Turns a light on or off
  Future<void> setPower(String lightId, bool on) async {
    final uri = _buildUri('/light', {'id': lightId, 'state': on ? 'on' : 'off'});
    await _sendCommand(SmartHomeVerb.power, uri);
  }
  
  /// Sets the brightness of a light
  Future<LightState> setBrightness(String lightId, int brightness) async {
    final uri = _buildUri('/light/brightness', {'id': lightId, 'value': brightness.toString()});
    final response = await _sendCommand(SmartHomeVerb.set, uri);
    return LightState.fromJson(response);
  }
  
  /// Gets the current status of a light
  Future<LightState> getLightStatus(String lightId) async {
    final uri = _buildUri('/light/status', {'id': lightId});
    final response = await _sendCommand(SmartHomeVerb.get, uri);
    return LightState.fromJson(response);
  }
  
  /// Builds a URI for the protocol
  Uri _buildUri(String path, Map<String, String> queryParams) {
    return Uri(
      scheme: 'smarthome',
      host: _deviceHost,
      port: _devicePort,
      path: path,
      queryParameters: queryParams,
    );
  }
  
  /// Sends a command and handles the response
  Future<dynamic> _sendCommand(SmartHomeVerb verb, Uri uri) async {
    final replyPort = ReceivePort();
    final completer = Completer<dynamic>();
    
    final packet = BusPacket(
      verb: verb,
      uri: uri,
      responsePort: replyPort.sendPort,
    );
    
    replyPort.listen((response) {
      if (response is BusPacket && response.isResponse) {
        if (response.success) {
          completer.complete(response.payload);
        } else {
          completer.completeError(SmartHomeException(
            response.errorCode?.toString() ?? 'UNKNOWN_ERROR',
            response.errorMessage ?? 'Unknown error',
          ));
        }
      } else {
        completer.completeError(SmartHomeException(
          'INVALID_RESPONSE',
          'Received invalid response format',
        ));
      }
      replyPort.close();
    });
    
    _sendPort.send(packet);
    return completer.future;
  }
}
```

### 4. Usage Example

Here's how you would use this protocol:

```dart
void main() async {
  // Create a bus
  final bus = SystemBus();
  
  // Create dispatcher with handler implementations
  final dispatcher = SmartHomeProtocolDispatcher(
    powerHandler: (device, id, state) async {
      print('Setting $id power to ${state ? 'on' : 'off'}');
      // Implementation...
    },
    setBrightnessHandler: (device, id, brightness) async {
      print('Setting $id brightness to $brightness');
      // Implementation...
      return LightState(isPowered: true, brightness: brightness);
    },
    getStatusHandler: (device, id) async {
      print('Getting status for $id');
      // Implementation...
      return LightState(isPowered: true, brightness: 75);
    },
  );
  
  // Set up device listener
  final stream = bus.bindListener('smarthome.lights', 1);
  stream.listen((packet) {
    // Pass along to dispatcher
    dispatcher.handlePacket(packet, 'device_context');
  });
  
  // Create client
  final client = SmartHomeClient(bus.sendPort, 'smarthome.lights', 1);
  
  // Use the client
  try {
    // Turn on a light
    await client.setPower('living_room', true);
    
    // Set brightness
    final newState = await client.setBrightness('living_room', 75);
    print('New brightness: ${newState.brightness}');
    
    // Get status
    final status = await client.getLightStatus('living_room');
    print('Light is ${status.isPowered ? 'on' : 'off'} at ${status.brightness}% brightness');
  } catch (e) {
    print('Error: $e');
  }
}
```

This pattern provides several benefits:
1. **Clean separation of concerns**: Client, dispatcher, and protocol definition are separate
2. **Type safety**: Protocol-specific types and enums provide compile-time checking
3. **Error handling**: Consistent error reporting and propagation
4. **Testability**: Each component can be tested in isolation
5. **Code organization**: Follows a structured pattern that scales well for complex protocols

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
  final dynamic payload;         // Operation parameters or response data
  final SendPort? responsePort;  // Direct response channel
  
  // For responses
  final bool isResponse;
  final bool success;
  final dynamic errorCode;       // Error code for failed responses
  final String? errorMessage;    // Error message for failed responses
  
  // Constructors and helper methods...
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
- **0.5.0**: Improved protocol structure and protocol-agnostic design
- **0.6.0**: Path-based routing with support for route parameters
- **0.7.0**: Pub/Sub pattern for topic-based event distribution
- **0.8.0**: Message filtering and validation capabilities
- **0.9.0**: Performance optimizations for high-frequency communications
- **1.0.0**: Stable API with comprehensive documentation

This roadmap serves as a guide and may be adjusted based on user feedback and evolving requirements.

## License

This package is available under the MIT License.

