import '../model/survey.dart';

abstract interface class SurveyRepository {
  /// The survey to show this customer, or null when there is nothing to show.
  ///
  /// Calling this **marks the survey as shown server-side**, even if the
  /// customer dismisses it without answering — a second call returns null. Only
  /// call it at the moment the popup is about to appear, never speculatively.
  Future<Survey?> activeSurvey();

  /// Submits the answers. The backend rejects a second submission for the same
  /// survey, so this is called once and its failure is not retried blindly.
  Future<void> respond(String surveyId, List<SurveyAnswer> answers);
}
