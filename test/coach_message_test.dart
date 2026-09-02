import 'package:fitmate/features/coach/presentation/coach_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson reads intent, previews, questions, and bullets', () {
    final CoachMessage message = CoachMessage.fromJson(<String, dynamic>{
      'role': 'assistant',
      'text': 'Want a lighter Monday?',
      'intent': 'clarify',
      'preview_lines': <String>['Add Push-up · 3 × 10 on Monday'],
      'clarifying_questions': <String>['Which day?', ''],
      'bullets': <String>['Keep protein high'],
      'requires_confirmation': true,
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'add_exercise'},
      ],
    });

    expect(message.intent, 'clarify');
    expect(message.previewLines, <String>['Add Push-up · 3 × 10 on Monday']);
    expect(message.clarifyingQuestions, <String>['Which day?']);
    expect(message.bullets, <String>['Keep protein high']);
    expect(message.requiresConfirmation, isTrue);
    expect(message.actions.single['type'], 'add_exercise');
  });

  test('round-trips through toJson', () {
    const CoachMessage original = CoachMessage(
      role: 'assistant',
      text: 'Done.',
      intent: 'propose',
      previewLines: <String>['Log chicken'],
      applied: true,
    );
    final CoachMessage parsed = CoachMessage.fromJson(original.toJson());
    expect(parsed.intent, 'propose');
    expect(parsed.previewLines, <String>['Log chicken']);
    expect(parsed.applied, isTrue);
  });
}
