import '../../domain/model/survey.dart';
import '../dto/survey_dto.dart';

abstract final class SurveyMapper {
  static SurveyQuestion questionToDomain(SurveyQuestionDto dto) =>
      SurveyQuestion(
        id: dto.id,
        text: dto.text,
        type: SurveyQuestionType.fromWire(dto.type),
        options: dto.options,
      );

  static Survey toDomain(SurveyDto dto) => Survey(
        id: dto.id,
        title: dto.title,
        description: dto.description,
        questions: dto.questions.map(questionToDomain).toList(),
      );

  /// Answer shape for `POST /food/user/survey/:id/respond`. The value is sent
  /// as-is — string, number, or list of strings — which is what the backend
  /// stores and the admin report reads back.
  static Map<String, dynamic> answerToJson(SurveyAnswer answer) => {
        'questionId': answer.questionId,
        'answer': answer.value,
      };
}
