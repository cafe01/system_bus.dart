import 'package:system_bus/system_bus.dart';

// Define custom protocol verbs
enum DeviceVerb { get, set, reboot, configure }

void main() async {
  // Create a bus instance
  final bus = SystemBus();

  // Set up a service that responds to status requests
  final deviceStream = bus.bindListener('device', 1);
  deviceStream.listen((packet) {
    if (packet.verb == DeviceVerb.get && packet.uri.path == '/status') {
      // Process the request and send a successful response
      bus.sendResponse(packet, {
        'status': 'online',
        'battery': 85,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } else if (packet.verb == DeviceVerb.configure) {
      // Demonstrate error handling with errorCode
      bus.sendResponse(
        packet,
        null,
        success: false,
        errorCode: 'PERMISSION_DENIED',
        errorMessage: 'Device configuration requires admin privileges',
      );
    }
  });

  print('Sending status request...');
  // Send a request using the sendRequest method
  try {
    final result = await bus.sendRequest(
      verb: DeviceVerb.get,
      uri: Uri.parse('device://device:1/status'),
      timeout: Duration(seconds: 5),
    );

    print('Device status: $result');

    // Demonstrate error handling by sending a configure request
    print('\nSending configuration request (this will fail)...');
    await bus.sendRequest(
      verb: DeviceVerb.configure,
      uri: Uri.parse('device://device:1/configure'),
      payload: {'setting': 'power_save', 'value': true},
      timeout: Duration(seconds: 5),
    );
  } catch (e) {
    print('Request failed: $e');
  }

  // Clean up
  bus.dispose();
}
