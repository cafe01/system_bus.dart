import 'package:logging/logging.dart';
import 'package:system_bus/src/bus_logger.dart';
import 'package:system_bus/system_bus.dart';

void main() async {
  // Initialize logging
  BusLogger.init(level: Level.INFO, includeCallerInfo: true);

  // Create a bus instance
  final bus = SystemBus();

  // Set up a service that responds to status requests
  final deviceStream = bus.bindListener('device', 1);
  deviceStream.listen((packet) {
    if (packet.verb == HttpVerb.get && packet.uri.path == '/status') {
      // Process the request and send a response
      bus.sendResponse(packet, {
        'status': 'online',
        'battery': 85,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  });

  // Send a request using the new sendRequest method
  try {
    final result = await bus.sendRequest(
      verb: HttpVerb.get,
      uri: Uri.parse('bus://device:1/status'),
      timeout: Duration(seconds: 5),
    );

    print('Device status: $result');
  } catch (e) {
    print('Request failed: $e');
  }

  // Clean up
  bus.dispose();
}
