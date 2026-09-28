/// How one survey question is answered, which decides how it renders.
enum SurveyQuestionType {
  text('text'),
  singleChoice('single-choice'),
  multipleChoice('multiple-choice'),
  rating('rating');

  const SurveyQuestionType(this.wireValue);

  final String wireValue;

  bool get isChoice =>
      this == SurveyQuestionType.singleChoice ||
      this == SurveyQuestionType.multipleChoice;

  static SurveyQuestionType fromWire(String? value) =>
      SurveyQuestionType.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => SurveyQuestionType.text,
      );
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
  });

  final String id;
  final String text;
  final SurveyQuestionType type;
  final List<String> options;

  /// A choice question with no options cannot be answered, so it is skipped
  /// rather than rendered as an empty group.
  bool get isAnswerable => !type.isChoice || options.isNotEmpty;
}

/// The highest rating a `rating` question offers. Fixed at 5 — the backend
/// stores whatever number it is sent and the admin UI collects out of five.
const int surveyRatingMax = 5;

class Survey {
  const Survey({
    required this.id,
    required this.title,
    required this.questions,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;
  final List<SurveyQuestion> questions;

  List<SurveyQuestion> get answerable =>
      questions.where((q) => q.isAnswerable).toList();

  bool get isEmpty => answerable.isEmpty;
}

/// One answer being submitted. [value] is a `String`, an `int` (rating), or a
/// `List<String>` (multiple choice) — the three shapes the backend accepts.
class SurveyAnswer {
  const SurveyAnswer({required this.questionId, required this.value});

  final String questionId;
  final Object value;

  /// Blank text and empty selections are dropped before submitting rather than
  /// sent as empty answers.
  bool get isAnswered => switch (value) {
        String v => v.trim().isNotEmpty,
        List v => v.isNotEmpty,
        num v => v > 0,
        _ => false,
      };
}
