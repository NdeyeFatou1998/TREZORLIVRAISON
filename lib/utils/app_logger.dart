/// Logger simple pour debug — désactivé en production.
class AppLogger {
  static const bool _enabled = true;

  static void log(String message) {
    if (_enabled) print('[LOG] $message');
  }

  static void error(String message, [dynamic error]) {
    if (_enabled) print('[ERR] $message${error != null ? ' — $error' : ''}');
  }
}
