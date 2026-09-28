import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin wrapper so log calls are greppable and stripped in release.
abstract final class AppLogger {
  static void debug(String message, {String scope = 'app'}) {
    if (kDebugMode) developer.log(message, name: 'suvio.$scope');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'suvio.error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
