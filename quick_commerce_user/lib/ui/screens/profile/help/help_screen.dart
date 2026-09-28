import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../data/repository_impl/api_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import '../../../common/widgets/inputs/search_bar_widget.dart';
import '../../../common/widgets/states/empty_state_widget.dart';

/// FAQ + support ticket. Tickets go to the backend's real support endpoint.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _faqs = [
    (
      'How fast is delivery?',
      'Most Suvio orders arrive in 8–15 minutes. The exact promise for your '
          'address is shown at checkout before you pay.'
    ),
    (
      'Can I change my order after placing it?',
      'You can cancel an order while it is still being confirmed. After that, '
          'reach out through Contact support and we will help.'
    ),
    (
      'When will I get my refund?',
      'Refunds for cancelled or undelivered orders are returned to the '
          'original payment method, typically within 3–5 working days.'
    ),
    (
      'Why is there a delivery fee?',
      'Delivery is priced by distance from the store fulfilling your order. '
          'The exact breakdown is always shown in your bill details.'
    ),
    (
      'An item was missing or damaged',
      'Open the order, tap Get help with this order and tell us what happened. '
          'We resolve most reports the same day.'
    ),
    (
      'How do I use a coupon?',
      'Open your cart, tap View offers, and apply any coupon you qualify for. '
          'The discount is applied by our servers before you pay.'
    ),
    (
      'Is my payment information safe?',
      'Payments are processed by our payment partner. Suvio never stores your '
          'card or UPI credentials.'
    ),
  ];

  List<(String, String)> get _filtered {
    if (_query.trim().length < 2) return _faqs;
    final q = _query.toLowerCase();
    return _faqs
        .where((f) => f.$1.toLowerCase().contains(q) || f.$2.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _contactSupport() async {
    if (!ref.read(authProvider).isSignedIn) {
      AppToast.error(context, 'Sign in to raise a support request');
      return;
    }

    final draft = await _SupportSheet.show(context);
    if (draft == null || !mounted) return;

    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.supportTicket,
        body: {
          'type': 'other',
          'issueType': draft.subject,
          'description': draft.message,
        },
        requiresAuth: true,
      );
      if (mounted) {
        AppToast.success(context, 'We have your request — we will be in touch');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not send your request');
    }
  }

  @override
  Widget build(BuildContext context) {
    final faqs = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SearchBarWidget(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (faqs.isEmpty)
              const EmptyStateWidget(
                icon: Icons.help_outline_rounded,
                title: 'No matching answers',
                message:
                    'Try a different word, or contact support and we will help directly.',
                compact: true,
              )
            else
              for (final faq in faqs)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadii.rLg,
                    border: Border.all(color: context.semantic.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: context.theme
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(faq.$1, style: context.text.titleMedium),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(faq.$2, style: context.text.bodyLarge),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Contact support',
              icon: Icons.support_agent_rounded,
              onPressed: _contactSupport,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Call us: 1800 000 0000',
              icon: Icons.call_rounded,
              expand: true,
              tonal: false,
              onPressed: () => AppToast.show(
                context,
                'Our phone line is open 7 AM – 11 PM',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _SupportDraft = ({String subject, String message});

class _SupportSheet extends StatefulWidget {
  static Future<_SupportDraft?> show(BuildContext context) =>
      AppBottomSheet.show<_SupportDraft>(
        context,
        title: 'Contact support',
        subtitle: 'Tell us what happened and we will pick it up',
        child: const _SupportSheet(),
      );

  const _SupportSheet();

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          AppTextField(
            controller: _subject,
            label: 'What is this about?',
            hint: 'e.g. Missing item in my order',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _message,
            label: 'Details',
            hint: 'Share anything that helps us resolve it faster',
            maxLines: 4,
            maxLength: 800,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Send request',
            onPressed: () {
              final subject = _subject.text.trim();
              if (subject.isEmpty) return;
              Navigator.of(context).pop((
                subject: subject,
                message: _message.text.trim(),
              ));
            },
          ),
        ],
      ),
    );
  }
}
