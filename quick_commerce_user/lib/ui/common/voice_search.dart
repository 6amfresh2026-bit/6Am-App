import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_theme.dart';
import 'widgets/feedback/app_toast.dart';

/// The search-bar microphone. Asks for the mic permission the first time it is
/// tapped (speech_to_text handles the OS prompt inside `initialize`), listens
/// through the device's own recogniser — so it honours whatever languages the
/// phone supports, English, Indian languages or Hinglish — and returns the
/// recognised text for the caller to drop into the search field and run.
///
/// Returns the spoken text, or null if nothing was captured / the user
/// cancelled / permission was denied.
abstract final class VoiceSearch {
  static Future<String?> run(BuildContext context) async {
    final speech = stt.SpeechToText();

    bool available;
    try {
      available = await speech.initialize(
        onError: (e) => debugPrint('VoiceSearch error: ${e.errorMsg}'),
      );
    } catch (e, s) {
      debugPrint('VoiceSearch init failed: $e\n$s');
      available = false;
    }

    if (!context.mounted) return null;
    if (!available) {
      AppToast.error(
        context,
        'Microphone access is needed for voice search. '
        'Please enable it in Settings and try again.',
      );
      return null;
    }

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      builder: (_) => _ListeningSheet(speech: speech),
    );
    final trimmed = text?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }
}

/// The live "listening" state: a pulsing mic, the words as they are recognised,
/// and a Stop button. Owns the recogniser session for its lifetime.
class _ListeningSheet extends StatefulWidget {
  const _ListeningSheet({required this.speech});

  final stt.SpeechToText speech;

  @override
  State<_ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<_ListeningSheet> {
  String _words = '';
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    // localeId left null: the device default respects the user's chosen
    // language, covering English, Indian languages and Hinglish where the
    // on-device recogniser supports them.
    await widget.speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _words = result.recognizedWords);
        if (result.finalResult) _finish(_words);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Closes the sheet exactly once, returning [value] to the caller.
  void _finish(String? value) {
    if (_popped || !mounted) return;
    _popped = true;
    widget.speech.stop();
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    widget.speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.speech.isListening;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingMic(active: listening),
            const SizedBox(height: 16),
            Text(
              listening ? 'Listening…' : 'Tap stop when you\'re done',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              _words.isEmpty ? 'Say a product, e.g. “Coca-Cola”' : _words,
              textAlign: TextAlign.center,
              style: _words.isEmpty
                  ? context.text.bodyMedium!
                      .copyWith(color: context.semantic.textSecondary)
                  : context.text.titleLarge!
                      .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _finish(null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _finish(_words),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A mic in a circle that gently pulses while active, as the listening cue.
class _PulsingMic extends StatefulWidget {
  const _PulsingMic({required this.active});

  final bool active;

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // const accent = Color(0xFFFFC107);
    const accent = Color(0xFF43B5A8);
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: widget.active
              ? accent.withValues(alpha: 0.18)
              : context.semantic.surfaceAlt,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic_rounded, size: 40, color: accent),
      ),
    );
  }
}
