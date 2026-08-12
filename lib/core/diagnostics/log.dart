import 'dart:developer' as developer;

/// Minimal logging facade for the app.
///
/// Replaces the ad-hoc `print()` calls that used to run on hot paths (every
/// tab-state mutation, every editor frame). Routes through `dart:developer` so
/// output lands in the DevTools log view with a channel name instead of being
/// interleaved into stdout, and compiles out of release builds.
///
/// [verbose] messages are additionally gated on the app's diagnostics toggle,
/// which callers pass in — this layer stays free of Riverpod so `core` does not
/// depend on the application layer.
class Log {
  const Log._();

  /// True in debug builds. Equivalent to Flutter's `kDebugMode`, spelled with
  /// plain Dart so `core` stays free of Flutter imports (see RULES.md).
  static const bool isDebug = !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');

  /// Debug-only trace. Silent in profile and release builds.
  static void debug(String channel, String message) {
    if (!isDebug) return;
    developer.log(message, name: channel);
  }

  /// Debug-only trace that also requires the diagnostics toggle to be on.
  static void verbose(bool enabled, String channel, String message) {
    if (!enabled) return;
    debug(channel, message);
  }

  /// Recoverable failure. Kept in all build modes — these are the cases that
  /// used to vanish into bare `catch (_) {}` blocks.
  static void warn(String channel, String message,
      [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: channel,
      level: 900, // WARNING
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Unrecoverable failure for the operation in progress.
  static void error(String channel, String message,
      [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: channel,
      level: 1000, // SEVERE
      error: error,
      stackTrace: stackTrace,
    );
  }
}
