import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/logger.dart';

/// A [RefreshIndicator] that plays the app's refresh cue when a pull actually
/// triggers a refresh.
///
/// Everything visual is delegated untouched to [RefreshIndicator] — same
/// spinner, same colours, same drag physics. The only addition is the sound.
///
/// The cue fires on the refresh *gesture*, never on a screen's initial load or
/// on a programmatic reload, because `onRefresh` is only invoked when the user
/// completes the pull.
class SoundRefreshIndicator extends StatefulWidget {
  const SoundRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.color,
    this.backgroundColor,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;
  final Color? color;
  final Color? backgroundColor;

  @override
  State<SoundRefreshIndicator> createState() => _SoundRefreshIndicatorState();
}

class _SoundRefreshIndicatorState extends State<SoundRefreshIndicator> {
  /// One player per indicator, reused across refreshes. Creating one per pull
  /// leaks a platform player on every gesture.
  AudioPlayer? _player;

  /// Guards against a second cue while the first is still playing — a fast
  /// double pull, or a widget rebuild mid-refresh, would otherwise stack them.
  bool _playing = false;

  @override
  void dispose() {
    // Release the platform resource; if a cue is mid-flight it stops with it.
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  Future<void> _playCue() async {
    if (_playing) return;
    _playing = true;
    try {
      final player = _player ??= AudioPlayer();
      // Restart rather than queue: a refresh cue that plays late is worse than
      // one that plays from the top.
      await player.stop();
      await player.play(AssetSource('sound/refersh.mp4'));
    } catch (e) {
      // A missing codec or a busy audio focus must never break the refresh
      // itself — the data reload is the point, the sound is decoration.
      AppLogger.debug('refresh cue failed: $e', scope: 'audio');
    } finally {
      _playing = false;
    }
  }

  Future<void> _handleRefresh() async {
    // Fires once per completed pull (RefreshIndicator only calls onRefresh at
    // the trigger threshold), so the cue never repeats mid-drag.
    AppHaptics.light();
    // Fire-and-forget: awaiting the cue would hold the spinner open for the
    // length of the audio instead of the length of the reload.
    unawaited(_playCue());
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: widget.displacement,
      edgeOffset: widget.edgeOffset,
      color: widget.color,
      backgroundColor: widget.backgroundColor,
      child: widget.child,
    );
  }
}
