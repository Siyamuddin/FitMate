import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/ai_cards.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/insight_card.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/coach/domain/ai_action_applier.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

class CoachMessage {
  const CoachMessage({
    required this.role,
    required this.text,
    this.actions = const <Map<String, dynamic>>[],
    this.requiresConfirmation = false,
    this.dismissed = false,
    this.applied = false,
  });

  final String role;
  final String text;
  final List<Map<String, dynamic>> actions;
  final bool requiresConfirmation;
  final bool applied;
  final bool dismissed;

  CoachMessage copyWith({bool? dismissed, bool? applied}) {
    return CoachMessage(
      role: role,
      text: text,
      actions: actions,
      requiresConfirmation: requiresConfirmation,
      dismissed: dismissed ?? this.dismissed,
      applied: applied ?? this.applied,
    );
  }

  factory CoachMessage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> actions = json['actions'] as List<dynamic>? ?? <dynamic>[];
    return CoachMessage(
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      requiresConfirmation: json['requires_confirmation'] == true,
      applied: json['applied'] == true,
      dismissed: json['dismissed'] == true,
      actions: actions.whereType<Map>().map((Map item) => Map<String, dynamic>.from(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role,
      'text': text,
      'actions': actions,
      'requires_confirmation': requiresConfirmation,
      'applied': applied,
      'dismissed': dismissed,
    };
  }
}

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final TextEditingController _input = TextEditingController();
  final List<CoachMessage> _messages = <CoachMessage>[];
  bool _sending = false;
  bool _applying = false;
  String? _error;
  String? _insight;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final store = ref.read(localStoreProvider);
    await store.ensureReady();
    final List<dynamic>? cached = await store.getList(SnapshotKeys.coachMessages);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cached.map((dynamic row) => CoachMessage.fromJson(Map<String, dynamic>.from(row as Map))));
        _insight = 'Ask about today\'s workout, dinner, or why weight is stalling.';
      });
      return;
    }
    setState(() => _insight = 'Ask about today\'s workout, dinner, or why weight is stalling.');
  }

  Future<void> _persist() async {
    await ref.read(localStoreProvider).setList(
      SnapshotKeys.coachMessages,
      _messages.map((CoachMessage message) => message.toJson()).toList(),
    );
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    if (!ref.read(syncStatusProvider).online) {
      setState(() => _error = 'Connect to talk to your coach.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(CoachMessage(role: 'user', text: text));
      _input.clear();
    });
    ref.read(analyticsServiceProvider).track('coach_message_sent');
    try {
      final Map<String, dynamic> response = await EdgeFunctions.invoke('coach-chat', body: <String, dynamic>{'message': text});
      final List<dynamic> actions = response['actions'] as List<dynamic>? ?? <dynamic>[];
      setState(() {
        _messages.add(
          CoachMessage(
            role: 'assistant',
            text: response['message'] as String? ?? 'I am here to help with your plan.',
            requiresConfirmation: response['requires_confirmation'] as bool? ?? false,
            actions: actions.map((dynamic item) => Map<String, dynamic>.from(item as Map)).toList(),
          ),
        );
      });
      await _persist();
      if (actions.isNotEmpty) {
        ref.read(analyticsServiceProvider).track('ai_action_proposed');
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _apply(int index, CoachMessage message) async {
    if (_applying) {
      return;
    }
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      await AiActionApplier(
        workouts: ref.read(workoutRepositoryProvider),
        profiles: ref.read(profileRepositoryProvider),
        store: ref.read(localStoreProvider),
      ).apply(message.actions);
      await AppHaptics.confirmation();
      ref.read(analyticsServiceProvider).track('ai_action_approved');
      if (!mounted) {
        return;
      }
      setState(() {
        _messages[index] = message.copyWith(applied: true);
        _messages.add(const CoachMessage(role: 'assistant', text: 'Saved to your plan.'));
      });
      await _persist();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  Future<void> _dismiss(int index, CoachMessage message) async {
    setState(() {
      _messages[index] = message.copyWith(dismissed: true);
    });
    await _persist();
  }

  String _actionSummary(List<Map<String, dynamic>> actions) {
    return actions.map((Map<String, dynamic> action) {
      final String type = action['type'] as String? ?? 'change';
      final Map<String, dynamic> changes = action['changes'] is Map
          ? Map<String, dynamic>.from(action['changes'] as Map)
          : <String, dynamic>{};
      if (type == 'update_training_plan' || type == 'create_workout_plan') {
        final Object? days = changes['days_per_week'];
        final Object? add = changes['add_workout_day'];
        final List<String> lines = <String>[];
        if (days != null) {
          lines.add('Train $days days per week');
        }
        if (changes['remove_workout_day_id'] != null || changes['remove_workout_day'] != null) {
          lines.add('Remove a training day');
        }
        final Object? removeWeekday = changes['remove_weekday'];
        if (removeWeekday is num) {
          lines.add('Drop ${Formatters.weekdayName(removeWeekday.toInt())}');
        }
        if (add is Map) {
          final Map<String, dynamic> day = Map<String, dynamic>.from(add);
          final String name = day['name'] as String? ?? 'New workout';
          final Object? weekday = day['weekday'];
          if (weekday is num) {
            lines.add('Add ${Formatters.weekdayName(weekday.toInt())}: $name');
          } else {
            lines.add('Add $name');
          }
        }
        if (lines.isNotEmpty) {
          return lines.join('\n');
        }
      }
      if (type == 'modify_workout_exercise') {
        final Object? sets = changes['sets'] ?? changes['target_sets'];
        final Object? reps = changes['reps'];
        if (sets != null && reps != null) {
          return 'Update exercise to $sets × $reps';
        }
        if (sets != null) {
          return 'Update sets to $sets';
        }
      }
      return type.replaceAll('_', ' ');
    }).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final bool online = ref.watch(syncStatusProvider).online;
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('AI Coach')),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          if (_insight != null) InsightCard(title: 'Your personal fitness coach', body: _insight!),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _messages.isEmpty
                ? EmptyState(
                    title: online ? 'Ask your coach' : 'Coach is offline',
                    message: online
                        ? 'Try “My workout yesterday was too difficult.”'
                        : 'Connect to the internet to talk to your coach. Applied plan changes stay on this device.',
                  )
                : ListView(
                    children: _messages.asMap().entries.map((MapEntry<int, CoachMessage> entry) {
                      final CoachMessage message = entry.value;
                      final bool mine = message.role == 'user';
                      return AIMessageBubble(
                        text: message.text,
                        isUser: mine,
                        child: message.requiresConfirmation && message.actions.isNotEmpty && !message.dismissed && !message.applied
                            ? AIActionCard(
                                summary: _actionSummary(message.actions),
                                applying: _applying,
                                onApply: () => _apply(entry.key, message),
                                onDismiss: () => _dismiss(entry.key, message),
                              )
                            : message.applied
                                ? Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                                    child: Semantics(
                                      label: 'Applied',
                                      child: Text('Applied', style: AppTypography.meta(AppColors.muted(brightness))),
                                    ),
                                  )
                                : null,
                      );
                    }).toList(),
                  ),
          ),
          if (_error != null) Text(_error!, style: AppTypography.meta(AppColors.danger)),
          if (!online)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text('Connect to talk to your coach', style: AppTypography.meta(AppColors.muted(brightness))),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _input,
                  placeholder: online ? 'Message your coach' : 'Connect to talk to your coach',
                  enabled: online && !_sending,
                  onSubmitted: (_) => _send(),
                ),
              ),
              Semantics(
                button: true,
                enabled: online && !_sending,
                label: 'Send',
                child: CupertinoButton(
                  onPressed: !online || _sending ? null : _send,
                  child: _sending ? const CupertinoActivityIndicator() : const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
