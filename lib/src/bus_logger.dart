import 'package:logging/logging.dart';

/// Logger configuration for SystemBus
class BusLogger {
  /// Get a logger for a specific component
  static Logger get(String name) {
    return Logger('system_bus.$name');
  }

  /// Log a message packet for debugging
  static void tracePacket(Logger logger, String direction, dynamic packet,
      {String? detail}) {
    if (logger.level <= Level.FINE) {
      final detailInfo = detail != null ? ' - $detail' : '';
      logger.fine('$direction PACKET$detailInfo:');
      logger.fine('  ${packet.toString()}');
    }
  }
}
