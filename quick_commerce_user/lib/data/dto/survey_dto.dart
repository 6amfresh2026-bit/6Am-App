import 'json_reader.dart';

class SurveyQuestionDto {
  const SurveyQuestionDto({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
  });

  final String id;
  final String text;
  final String type;
  final List<String> options;

  factory SurveyQuestionDto.fromJson(Map<String, dynamic> json) =>
      SurveyQuestionDto(
        id: json.id(),
        text: json.str('text'),
        type: json.str('type', 'text'),
        options: json.strings('options'),
      );
}

class SurveyDto {
  const SurveyDto({
    required this.id,
    required this.title,
    required this.questions,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;
  final List<SurveyQuestionDto> questions;

  factory SurveyDto.fromJson(Map<String, dynamic> json) => SurveyDto(
        id: json.id(),
        title: json.str('title'),
        description: json.str('description'),
        questions:
            json.objects('questions').map(SurveyQuestionDto.fromJson).toList(),
      );
}
