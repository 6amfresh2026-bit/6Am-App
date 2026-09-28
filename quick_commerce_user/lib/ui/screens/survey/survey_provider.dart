import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/survey.dart';

class SurveyState {
  const SurveyState({
    this.survey,
    this.answers = const {},
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.failure,
  });

  final Survey? survey;

  /// questionId → the answer so far: `String`, `int`, or `List<String>`.
  final Map<String, Object> answers;
  final bool isSubmitting;
  final bool isSubmitted;
  final Failure? failure;

  /// The survey is optional, so submitting is allowed as soon as anything has
  /// been answered — customers are not forced through every question.
  bool get hasAnyAnswer => toAnswers().isNotEmpty;

  List<SurveyAnswer> toAnswers() => answers.entries
      .map((e) => SurveyAnswer(questionId: e.key, value: e.value))
      .where((a) => a.isAnswered)
      .toList();

  SurveyState copyWith({
    Survey? survey,
    Map<String, Object>? answers,
    bool? isSubmitting,
    bool? isSubmitted,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      SurveyState(
        survey: survey ?? this.survey,
        answers: answers ?? this.answers,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class SurveyController extends Notifier<SurveyState> {
  @override
  SurveyState build() => const SurveyState();

  /// Fetches the survey to show, if any.
  ///
  /// **This marks the survey as shown server-side**, so it is called only at
  /// the moment the popup is about to be displayed — never on a timer, never
  /// speculatively. A second call returns nothing.
  Future<Survey?> fetchForDisplay() async {
    try {
      final survey = await ref.read(surveyRepositoryProvider).activeSurvey();
      if (survey == null || survey.isEmpty) return null;
      state = SurveyState(survey: survey);
      return survey;
    } catch (e) {
      // A failed survey check must never block the app opening, so this is
      // recorded and swallowed rather than surfaced to the customer.
      state = state.copyWith(failure: ErrorMapper.toFailure(e));
      return null;
    }
  }

  void answer(String questionId, Object value) {
    state = state.copyWith(
      answers: {...state.answers, questionId: value},
      clearFailure: true,
    );
  }

  /// Toggles one option of a multiple-choice question.
  void toggleChoice(String questionId, String option) {
    final current = state.answers[questionId];
    final selected = current is List<String> ? [...current] : <String>[];
    if (selected.contains(option)) {
      selected.remove(option);
    } else {
      selected.add(option);
    }
    answer(questionId, selected);
  }

  bool isChosen(String questionId, String option) {
    final current = state.answers[questionId];
    if (current is List<String>) return current.contains(option);
    return current == option;
  }

  Future<bool> submit() async {
    final survey = state.survey;
    if (survey == null || state.isSubmitting) return false;

    final answers = state.toAnswers();
    if (answers.isEmpty) return false;

    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      await ref.read(surveyRepositoryProvider).respond(survey.id, answers);
      state = state.copyWith(isSubmitting: false, isSubmitted: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        failure: ErrorMapper.toFailure(e),
      );
      return false;
    }
  }
}

final surveyProvider =
    NotifierProvider<SurveyController, SurveyState>(SurveyController.new);
