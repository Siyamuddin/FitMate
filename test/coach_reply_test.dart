import 'package:fitmate/features/coach/domain/coach_reply.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';

void main() {
  test('answer drops actions so no card is shown', () {
    final CoachReply reply = parseCoachReply(<String, dynamic>{
      'intent': 'answer',
      'message': 'Rest more this week.',
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'add_exercise'},
      ],
    });
    expect(reply.actions, isEmpty);
    expect(reply.requiresConfirmation, isFalse);
    expect(reply.text, 'Rest more this week.');
  });

  test('clarify keeps questions and no actions', () {
    final CoachReply reply = parseCoachReply(<String, dynamic>{
      'intent': 'clarify',
      'message': 'Which day should change?',
      'clarifying_questions': <String>['Monday?', 'Friday?'],
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'add_exercise'},
      ],
    });
    expect(reply.actions, isEmpty);
    expect(reply.clarifyingQuestions, <String>['Monday?', 'Friday?']);
  });

  test('propose uses preview lines and falls back to ActionPreview', () {
    final CoachReply withPreview = parseCoachReply(<String, dynamic>{
      'intent': 'propose',
      'message': 'I can add this.',
      'preview_lines': <String>['Add Push-up · 3 × 10 on Monday'],
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'add_exercise',
          'changes': <String, dynamic>{
            'exercise_name': 'Push-up',
            'sets': 3,
            'reps': 10,
            'weekday': 1,
          },
        },
      ],
    });
    expect(withPreview.requiresConfirmation, isTrue);
    expect(withPreview.previewLines.single, 'Add Push-up · 3 × 10 on Monday');

    final CoachReply fallback = parseCoachReply(<String, dynamic>{
      'intent': 'propose',
      'message': 'I can add this.',
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'add_exercise',
          'target_id': 'day-mon',
          'changes': <String, dynamic>{
            'exercise_name': 'Push-up',
            'sets': 3,
            'reps': 10,
          },
        },
      ],
    }, plan: testPlan);
    expect(fallback.previewLines.single, 'Add Push-up · 3 × 10 on Monday');
  });
}
