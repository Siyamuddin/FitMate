import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_motion.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/ai_cards.dart';
import 'package:fitmate/features/coach/domain/ai_action_applier.dart';
import 'package:fitmate/features/coach/presentation/coach_composer.dart';
import 'package:fitmate/features/coach/presentation/coach_empty_state.dart';
import 'package:fitmate/features/coach/presentation/coach_thinking.dart';
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
    this.failed = false,
  });

  final String role;
  final String text;
  final List<Map<String, dynamic>> actions;
  final bool requiresConfirmation;
  final bool applied;
  final bool dismissed;
  final bool failed;

  CoachMessage copyWith({bool? dismissed, bool? applied, bool? failed}) {
    return CoachMessage(
      role: role,
      text: text,
      actions: actions,
      requiresConfirmation: requiresConfirmation,
      dismissed: dismissed ?? this.dismissed,
      applied: applied ?? this.applied,
      failed: failed ?? this.failed,
    );
  }

  factory CoachMessage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> actions =
        json['actions'] as List<dynamic>? ?? <dynamic>[];
    return CoachMessage(
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      requiresConfirmation: json['requires_confirmation'] == true,
      applied: json['applied'] == true,
      dismissed: json['dismissed'] == true,
      failed: json['failed'] == true,
      actions: actions
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList(),
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
      'failed': failed,
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
  final ScrollController _scroll = ScrollController();
  final List<CoachMessage> _messages = <CoachMessage>[];
  bool _sending = false;
  bool _applying = false;
  bool _startFresh = false;
  int _sendGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = ref.read(localStoreProvider);
    await store.ensureReady();
    final List<dynamic>? cached = await store.getList(
      SnapshotKeys.coachMessages,
    );
    if (!mounted) {
      return;
    }
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(
            cached.map(
              (dynamic row) =>
                  CoachMessage.fromJson(Map<String, dynamic>.from(row as Map)),
            ),
          );
      });
    }
  }

  Future<void> _persist() async {
    await ref
        .read(localStoreProvider)
        .setList(
          SnapshotKeys.coachMessages,
          _messages.map((CoachMessage message) => message.toJson()).toList(),
        );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      final Duration duration = AppMotion.durationOf(context);
      if (duration == Duration.zero) {
        _scroll.jumpTo(0);
        return;
      }
      _scroll.animateTo(0, duration: duration, curve: AppMotion.curve);
    });
  }

  Future<void> _send({String? preset, int? retryIndex}) async {
    final String text =
        (preset ??
                (retryIndex != null ? _messages[retryIndex].text : _input.text))
            .trim();
    if (text.isEmpty || _sending) {
      return;
    }
    if (!ref.read(syncStatusProvider).online) {
      setState(() => _error = 'Connect to talk to your coach.');
      return;
    }

    final int generation = ++_sendGeneration;
    setState(() {
      _sending = true;
      _error = null;
      if (retryIndex != null) {
        _messages[retryIndex] = _messages[retryIndex].copyWith(failed: false);
      } else {
        _messages.add(CoachMessage(role: 'user', text: text));
        _input.clear();
      }
    });
    _scrollToLatest();
    await AppHaptics.confirmation();
    ref.read(analyticsServiceProvider).track('coach_message_sent');

    final int userIndex = retryIndex ?? _messages.length - 1;
    try {
      final Map<String, dynamic> body = <String, dynamic>{'message': text};
      if (_startFresh) {
        body['new_conversation'] = true;
      }
      final Map<String, dynamic> response = await EdgeFunctions.invoke(
        'coach-chat',
        body: body,
      );
      final List<dynamic> actions =
          response['actions'] as List<dynamic>? ?? <dynamic>[];
      if (!mounted || generation != _sendGeneration) {
        return;
      }
      setState(() {
        _startFresh = false;
        _messages.add(
          CoachMessage(
            role: 'assistant',
            text:
                response['message'] as String? ??
                'I am here to help with your plan.',
            requiresConfirmation:
                response['requires_confirmation'] as bool? ?? false,
            actions: actions
                .map((dynamic item) => Map<String, dynamic>.from(item as Map))
                .toList(),
          ),
        );
      });
      _scrollToLatest();
      await _persist();
      if (actions.isNotEmpty) {
        ref.read(analyticsServiceProvider).track('ai_action_proposed');
      }
    } catch (error) {
      if (!mounted || generation != _sendGeneration) {
        return;
      }
      setState(() {
        _messages[userIndex] = _messages[userIndex].copyWith(failed: true);
        _error = ErrorMapper.map(error).message;
      });
      await _persist();
    } finally {
      if (mounted && generation == _sendGeneration) {
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
      });
      await _persist();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ErrorMapper.map(error).message);
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

  Future<void> _confirmNewChat() async {
    if (_messages.isEmpty && !_sending) {
      return;
    }
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Start a new chat?'),
          content: const Text('This conversation stays in history.'),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    _sendGeneration++;
    setState(() {
      _messages.clear();
      _error = null;
      _sending = false;
      _applying = false;
      _startFresh = true;
      _input.clear();
    });
    await _persist();
  }

  String _actionSummary(List<Map<String, dynamic>> actions) {
    return actions
        .map((Map<String, dynamic> action) {
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
            if (changes['remove_workout_day_id'] != null ||
                changes['remove_workout_day'] != null) {
              lines.add('Remove a training day');
            }
            final Object? removeWeekday = changes['remove_weekday'];
            if (removeWeekday is num) {
              lines.add(
                'Drop ${Formatters.weekdayName(removeWeekday.toInt())}',
              );
            }
            if (add is Map) {
              final Map<String, dynamic> day = Map<String, dynamic>.from(add);
              final String name = day['name'] as String? ?? 'New workout';
              final Object? weekday = day['weekday'];
              if (weekday is num) {
                lines.add(
                  'Add ${Formatters.weekdayName(weekday.toInt())}: $name',
                );
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
        })
        .join('\n');
  }

  Widget _messageRow(int index, CoachMessage message) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool mine = message.role == 'user';
    final bool showAction =
        !mine &&
        message.requiresConfirmation &&
        message.actions.isNotEmpty &&
        !message.dismissed &&
        !message.applied;

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        AIMessageBubble(text: message.text, isUser: mine),
        if (showAction)
          AIActionCard(
            summary: _actionSummary(message.actions),
            applying: _applying,
            onApply: () => _apply(index, message),
            onDismiss: () => _dismiss(index, message),
          ),
        if (!mine && message.applied) const AIAppliedLabel(),
        if (mine && message.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: Text(
                    _error ?? 'Could not send.',
                    style: AppTypography.meta(AppColors.danger),
                    textAlign: TextAlign.right,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: const Size(AppSpacing.minTap, AppSpacing.minTap),
                  onPressed: _sending ? null : () => _send(retryIndex: index),
                  child: Semantics(
                    button: true,
                    label: 'Try again',
                    child: Text(
                      'Try again',
                      style: AppTypography.meta(AppColors.accent(brightness)),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool online = ref.watch(syncStatusProvider).online;
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final int extra = _sending ? 1 : 0;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(brightness),
      resizeToAvoidBottomInset: false,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Coach'),
        trailing: Semantics(
          button: true,
          enabled: _messages.isNotEmpty || _sending,
          label: 'New chat',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(AppSpacing.minTap, AppSpacing.minTap),
            onPressed: _messages.isEmpty && !_sending ? null : _confirmNewChat,
            child: const Icon(CupertinoIcons.square_pencil),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _messages.isEmpty && !_sending
                  ? CoachEmptyState(
                      online: online,
                      onPrompt: (String prompt) => _send(preset: prompt),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.md,
                        AppSpacing.page,
                        AppSpacing.sm,
                      ),
                      itemCount: _messages.length + extra,
                      itemBuilder: (BuildContext context, int index) {
                        if (_sending && index == 0) {
                          return const CoachThinkingRow();
                        }
                        final int messageIndex =
                            _messages.length -
                            1 -
                            (_sending ? index - 1 : index);
                        return _messageRow(
                          messageIndex,
                          _messages[messageIndex],
                        );
                      },
                    ),
            ),
            if (_error != null &&
                _messages.every((CoachMessage message) => !message.failed))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: AppTypography.meta(AppColors.danger),
                  ),
                ),
              ),
            CoachComposer(
              controller: _input,
              online: online,
              enabled: !_sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
