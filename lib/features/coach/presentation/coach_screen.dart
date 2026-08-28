import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/ai_cards.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/insight_card.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

class CoachMessage {
  const CoachMessage({
    required this.role,
    required this.text,
    this.actions = const <Map<String, dynamic>>[],
    this.requiresConfirmation = false,
    this.dismissed = false,
  });

  final String role;
  final String text;
  final List<Map<String, dynamic>> actions;
  final bool requiresConfirmation;
  final bool dismissed;

  CoachMessage copyWith({bool? dismissed}) {
    return CoachMessage(
      role: role,
      text: text,
      actions: actions,
      requiresConfirmation: requiresConfirmation,
      dismissed: dismissed ?? this.dismissed,
    );
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
  String? _error;
  String? _insight;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final List<dynamic> rows = await SupabaseProvider.client
          .from('ai_messages')
          .select('role, content, conversation_id, ai_conversations!inner(user_id)')
          .order('created_at')
          .limit(20);
      setState(() {
        _messages.addAll(
          rows.map((dynamic row) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
            final dynamic content = json['content'];
            final String text = content is Map ? (content['message'] as String? ?? content.toString()) : content.toString();
            return CoachMessage(role: json['role'] as String, text: text);
          }),
        );
        _insight = 'Ask about today\'s workout, dinner, or why weight is stalling.';
      });
    } catch (_) {
      setState(() => _insight = 'Your coach uses your actual training and nutrition data.');
    }
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) {
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

  Future<void> _apply(CoachMessage message) async {
    await EdgeFunctions.invoke('apply-ai-action', body: <String, dynamic>{'actions': message.actions});
    await AppHaptics.confirmation();
    ref.read(analyticsServiceProvider).track('ai_action_approved');
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.add(const CoachMessage(role: 'assistant', text: 'Changes applied to your plan.'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('AI Coach')),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          if (_insight != null) InsightCard(title: 'Your personal fitness coach', body: _insight!),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(title: 'Ask your coach', message: 'Try “My workout yesterday was too difficult.”')
                : ListView(
                    children: _messages.asMap().entries.map((MapEntry<int, CoachMessage> entry) {
                      final CoachMessage message = entry.value;
                      final bool mine = message.role == 'user';
                      return AIMessageBubble(
                        text: message.text,
                        isUser: mine,
                        child: message.requiresConfirmation && message.actions.isNotEmpty && !message.dismissed
                            ? AIActionCard(
                                summary: message.actions
                                    .map((Map<String, dynamic> action) => '${action['type']} ${action['changes'] ?? action['target_id'] ?? ''}')
                                    .join('\n'),
                                onApply: () => _apply(message),
                                onDismiss: () {
                                  setState(() {
                                    _messages[entry.key] = message.copyWith(dismissed: true);
                                  });
                                },
                              )
                            : null,
                      );
                    }).toList(),
                  ),
          ),
          if (_error != null) Text(_error!, style: AppTypography.meta(AppColors.danger)),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _input,
                  placeholder: 'Message your coach',
                  onSubmitted: (_) => _send(),
                ),
              ),
              CupertinoButton(
                onPressed: _sending ? null : _send,
                child: _sending ? const CupertinoActivityIndicator() : const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
