import '../../core/network/api_client.dart';
import '../../domain/model/survey.dart';
import '../../domain/repository/survey_repository.dart';
import '../dto/json_reader.dart';
import '../dto/survey_dto.dart';
import '../mapper/survey_mapper.dart';
import 'api_paths.dart';

class ApiSurveyRepository implements SurveyRepository {
  ApiSurveyRepository(this._client);

  final ApiClient _client;

  @override
  Future<Survey?> activeSurvey() async {
    final json = await _client.get(ApiPaths.activeSurvey, requiresAuth: true);
    if (json is! Map<String, dynamic>) return null;

    // `{survey: null}` is the normal "nothing to show" answer, not an error:
    // no active survey, this user predates it, or they have already seen it.
    final survey = json.mapOrNull('survey');
    if (survey == null || survey.isEmpty) return null;

    return SurveyMapper.toDomain(SurveyDto.fromJson(survey));
  }

  @override
  Future<void> respond(String surveyId, List<SurveyAnswer> answers) =>
      _client.post(
        ApiPaths.surveyRespond(surveyId),
        body: {
          'answers': answers.map(SurveyMapper.answerToJson).toList(),
        },
        requiresAuth: true,
      );
}
