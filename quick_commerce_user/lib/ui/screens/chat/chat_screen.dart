import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/chat_message.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'chat_provider.dart';

/// Extra passed to the chat route so the header can name the rider without a
/// re-fetch. Everything the chat itself needs is derived from the order id.
class ChatArgs {
  const ChatArgs({this.riderName = 'Delivery partner', this.riderId = ''});
  final String riderName;
  final String riderId;
}

/// Customer↔rider chat for one order. Opened from order tracking once a rider is
/// assigned. Messages are sent over REST and arrive live over the shared socket.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.orderId,
    this.riderName = 'Delivery partner',
    this.riderId = '',
  });

  final String orderId;
  final String riderName;
  final String riderId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground: the OS may have frozen the socket. Nudge it
    // back and reconcile any messages missed while away.
    if (state == AppLifecycleState.resumed) {
      ref.read(realtimeSocketProvider).reconnect();
      ref.read(chatProvider(widget.orderId).notifier).refresh();
    }
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider(widget.orderId).notifier).send(text);
    _input.clear();
    ref
        .read(chatProvider(widget.orderId).notifier)
        .setTyping(false, riderId: widget.riderId);
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.orderId));

    // Auto-scroll when a new message lands.
    if (state.messages.length != _lastCount) {
      _lastCount = state.messages.length;
      _jumpToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.riderName, style: context.text.titleMedium),
            Text(
              state.riderTyping
                  ? 'typing…'
                  : (state.isConnected ? 'Online' : 'Connecting…'),
              style: context.text.bodySmall!.copyWith(
                color: state.isConnected
                    ? context.semantic.success
                    : context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _messages(context, state)),
            _composer(context, state),
          ],
        ),
      ),
    );
  }

  Widget _messages(BuildContext context, ChatState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.messages.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(chatProvider(widget.orderId).notifier).refresh(),
      );
    }
    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: context.semantic.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Say hello to your delivery partner',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium!
                    .copyWith(color: context.semantic.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.messages.length,
      itemBuilder: (context, i) => _Bubble(message: state.messages[i]),
    );
  }

  Widget _composer(BuildContext context, ChatState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.semantic.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onChanged: (v) => ref
                  .read(chatProvider(widget.orderId).notifier)
                  .setTyping(v.trim().isNotEmpty, riderId: widget.riderId),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message your delivery partner',
                filled: true,
                fillColor: context.semantic.surfaceAlt,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.rPill,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: context.colors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: state.isSending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.send_rounded,
                  color: context.colors.onPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bg = mine ? context.colors.primary : context.semantic.surfaceAlt;
    final fg = mine ? context.colors.onPrimary : context.colors.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: context.text.bodyMedium!.copyWith(color: fg)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(message.createdAt),
                  style: context.text.labelSmall!.copyWith(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.pending
                        ? Icons.schedule_rounded
                        : (message.readAt != null
                            ? Icons.done_all_rounded
                            : Icons.done_rounded),
                    size: 12,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}
