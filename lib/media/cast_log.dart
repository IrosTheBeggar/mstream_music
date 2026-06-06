import 'dart:developer' as developer;

import '../singletons/log_manager.dart';

/// Structured logging for the casting subsystem (the DLNA + Chromecast
/// backends and their discoverers).
///
/// Routes through `dart:developer` so messages carry a `cast` source tag and
/// an attached error/stack object instead of bare `print()` calls — they stay
/// filterable in `adb logcat` / DevTools (filter on the `cast` name) and are
/// lint-clean (no `avoid_print` ignores needed).
///
/// These are diagnostic logs for *caught, non-fatal* failures: a renderer that
/// won't load a track, a discovery backend that won't start. Failures the user
/// actually needs to know about are surfaced separately, via
/// [CastManager.reportCastFailed] → an on-screen toast, not from here.
///
/// (Crash reporting — Sentry/Crashlytics — is a separate, app-wide decision;
/// when one is added, this is the single place to forward cast diagnostics to
/// it.)
void castLog(String message, {Object? error, StackTrace? stackTrace}) {
  developer.log(message, name: 'cast', error: error, stackTrace: stackTrace);
  // Mirror into the in-app diagnostic buffer (developer.log doesn't go through
  // the print Zone) so the cast diagnostics show up on the Diagnostics screen.
  LogManager().add(error == null ? '[cast] $message' : '[cast] $message: $error');
}
