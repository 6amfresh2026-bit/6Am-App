import 'package:flutter/services.dart';

/// One place for every haptic in the app.
///
/// Intensity maps to meaning, not to a widget:
/// - [selection] — moving between choices (tabs, variants, filters, toggles).
/// - [light] — an ordinary tap landed (buttons, quantity ±, pull-to-refresh).
/// - [medium] — a committing action (add to cart, confirm).
/// - [heavy] — a destructive or critical action (delete, remove).
/// - [success] / [error] — the *outcome* of a flow (order placed, payment).
///
/// Rules that keep it professional:
/// - Fire on discrete user actions only — never in `build`, on scroll, or on a
///   rebuild. Each call site is a single gesture or a single flow result.
/// - `HapticFeedback` routes through the platform, which already honours the
///   device's system haptic/vibration setting, so a user who has haptics off
///   feels nothing. No app-level toggle re-implements what the OS owns.
/// - Every call is fire-and-forget; a platform that has no vibrator simply does
///   nothing rather than throwing.
abstract final class AppHaptics {
  /// Tabs, variant chips, filter/sort options, switches — anything that moves a
  /// selection. The lightest, crispest cue.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// A normal button tap or quantity step.
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// A committing action: add to cart, apply coupon, confirm a choice.
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Destructive or critical: delete an address, remove a cart line, sign out.
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// The positive end of a flow — order placed, payment captured. A single
  /// medium pulse reads as a confident "done" without the buzziness of a
  /// pattern. (Android has no dedicated notification haptic; this is the
  /// closest subtle equivalent.)
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// The negative end of a flow — payment declined, order rejected. Heavy so it
  /// is clearly distinct from the success pulse.
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
