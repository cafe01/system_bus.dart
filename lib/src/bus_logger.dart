import 'package:logging/logging.dart';

/// Logger configuration for SystemBus
class BusLogger {
  static final Logger _root = Logger('system_bus');
  static bool _initialized = false;

  /// Initialize the logging system with the specified level
  static void init({
    Level level = Level.INFO,
    bool includeCallerInfo = false,
  }) {
    if (_initialized) return;

    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      final callerInfo = includeCallerInfo ? ' [${record.loggerName}]' : '';
      print(
          '${record.level.name}: ${record.time}$callerInfo: ${record.message}');

      if (record.error != null) {
        print('ERROR: ${record.error}');
      }

      if (record.stackTrace != null) {
        print('STACKTRACE:\n${record.stackTrace}');
      }
    });

    _initialized = true;
    _root.info('SystemBus logging initialized at level ${level.name}');
  }

  /// Get a logger for a specific component
  static Logger get(String name) {
    if (!_initialized) {
      init();
    }
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
