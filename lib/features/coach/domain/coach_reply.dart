import 'package:fitmate/features/coach/domain/action_preview.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

class CoachReply {
  const CoachReply({
    required this.text,
    required this.actions,
    required this.previewLines,
    required this.clarifyingQuestions,
    required this.bullets,
    this.intent,
    this.requiresConfirmation = false,
  });

  final String text;
  final String? intent;
  final List<Map<String, dynamic>> actions;
  final List<String> previewLines;
  final List<String> clarifyingQuestions;
  final List<String> bullets;
  final bool requiresConfirmation;
}

List<String> coachStringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }
  return value
      .map((dynamic item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

CoachReply parseCoachReply(
  Map<String, dynamic> response, {
  WorkoutPlan? plan,
}) {
  final String? intent = response['intent'] as String?;
  final List<dynamic> raw =
      response['actions'] as List<dynamic>? ?? <dynamic>[];
  final List<Map<String, dynamic>> parsed = raw
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList();
  final bool propose =
      intent == 'propose' || (intent == null && parsed.isNotEmpty);
  final List<Map<String, dynamic>> actions =
      propose ? parsed : <Map<String, dynamic>>[];
  List<String> preview = coachStringList(response['preview_lines']);
  if (preview.isEmpty && actions.isNotEmpty) {
    preview = ActionPreview.lines(actions, plan: plan);
  }
  return CoachReply(
    text:
        response['message'] as String? ?? 'I am here to help with your plan.',
    intent: intent,
    actions: actions,
    previewLines: preview,
    clarifyingQuestions: coachStringList(response['clarifying_questions']),
    bullets: coachStringList(response['bullets']),
    requiresConfirmation: propose && actions.isNotEmpty
        ? (response['requires_confirmation'] as bool? ?? true)
        : false,
  );
}
