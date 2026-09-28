import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/model/survey.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/inputs/app_text_field.dart';
import 'survey_provider.dart';

/// The welcome survey shown once to new customers.
///
/// Fetching the survey is what marks it as seen server-side, so this is only
/// ever called at the moment the popup is about to appear — see
/// [SurveyController.fetchForDisplay]. Dismissing without answering is fine and
/// still counts as shown, which is the intended product behaviour.
abstract final class SurveyPopup {
  static Future<void> showIfAvailable(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final survey = await ref.read(surveyProvider.notifier).fetchForDisplay();
    if (survey == null || !context.mounted) return;

    await AppBottomSheet.show<void>(
      context,
      title: survey.title.isEmpty ? 'Quick question' : survey.title,
      subtitle: survey.description.isEmpty ? null : survey.description,
      expand: true,
      child: const _SurveyBody(),
    );
  }
}

class _SurveyBody extends ConsumerWidget {
  const _SurveyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(surveyProvider);
    final survey = state.survey;
    if (survey == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...survey.answerable.map(
          (question) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: _Question(question: question),
          ),
        ),
        PrimaryButton(
          label: 'Submit',
          isLoading: state.isSubmitting,
          // Answering is optional, but an empty submission would just be
          // rejected — so the button waits for at least one answer.
          onPressed: state.hasAnyAnswer && !state.isSubmitting
              ? () => _submit(context, ref)
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Maybe later'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(surveyProvider.notifier).submit();
    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).maybePop();
      AppToast.success(context, 'Thanks for the feedback!');
      return;
    }
    AppToast.error(
      context,
      ref.read(surveyProvider).failure?.message ??
          'Could not send your answers.',
    );
  }
}

class _Question extends ConsumerWidget {
  const _Question({required this.question});

  final SurveyQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.text, style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        switch (question.type) {
          SurveyQuestionType.text => _TextAnswer(question: question),
          SurveyQuestionType.rating => _RatingAnswer(question: question),
          SurveyQuestionType.singleChoice ||
          SurveyQuestionType.multipleChoice =>
            _ChoiceAnswer(question: question),
        },
      ],
    );
  }
}

class _TextAnswer extends ConsumerStatefulWidget {
  const _TextAnswer({required this.question});

  final SurveyQuestion question;

  @override
  ConsumerState<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends ConsumerState<_TextAnswer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      hint: 'Type your answer',
      maxLines: 3,
      onChanged: (value) =>
          ref.read(surveyProvider.notifier).answer(widget.question.id, value),
    );
  }
}

class _RatingAnswer extends ConsumerWidget {
  const _RatingAnswer({required this.question});

  final SurveyQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(surveyProvider).answers[question.id];
    final rating = current is int ? current : 0;

    return Row(
      children: List.generate(surveyRatingMax, (index) {
        final value = index + 1;
        return IconButton(
          onPressed: () =>
              ref.read(surveyProvider.notifier).answer(question.id, value),
          icon: Icon(
            value <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: value <= rating
                ? context.semantic.warning
                : context.semantic.textSecondary,
            size: 32,
          ),
        );
      }),
    );
  }
}

class _ChoiceAnswer extends ConsumerWidget {
  const _ChoiceAnswer({required this.question});

  final SurveyQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(surveyProvider.notifier);
    // Watched so the chips repaint when the answer map changes.
    ref.watch(surveyProvider);
    final multiple = question.type == SurveyQuestionType.multipleChoice;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: question.options.map((option) {
        final selected = notifier.isChosen(question.id, option);
        return ChoiceChip(
          label: Text(option),
          selected: selected,
          shape: const StadiumBorder(),
          onSelected: (_) => multiple
              ? notifier.toggleChoice(question.id, option)
              : notifier.answer(question.id, option),
        );
      }).toList(),
    );
  }
}
