import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/health/data/health_repository.dart';
import 'package:fitmate/services/health/health_service.dart';

final healthRepositoryProvider = Provider<HealthRepository>((Ref ref) {
  return HealthRepository(service: ref.watch(healthServiceProvider));
});

class HealthConnectionsScreen extends ConsumerStatefulWidget {
  const HealthConnectionsScreen({super.key});

  @override
  ConsumerState<HealthConnectionsScreen> createState() => _HealthConnectionsScreenState();
}

class _HealthConnectionsScreenState extends ConsumerState<HealthConnectionsScreen> {
  bool _connected = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final bool connected = await ref.read(healthRepositoryProvider).isConnected();
    if (mounted) {
      setState(() => _connected = connected);
    }
  }

  Future<void> _handleConnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(healthRepositoryProvider).requestPermissions();
      await ref.read(healthRepositoryProvider).syncToday();
      ref.invalidate(todayHealthProvider);
      if (mounted) {
        setState(() => _connected = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        await showCupertinoDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Apple Health permission needed'),
              content: const Text(
                'FitMate cannot turn Health on by itself. Open Settings → Health → Access → FitMate if you want steps and energy on Home.',
              ),
              actions: <Widget>[
                CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Apple Health')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'FitMate can read steps, sleep, and active energy. iOS owns this permission. FitMate never fakes a toggle.',
            style: AppTypography.body(AppColors.ink(brightness)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _connected ? 'Connected. Steps can appear on Home after a sync.' : 'Not connected.',
            style: AppTypography.meta(_connected ? AppColors.success : AppColors.muted(brightness)),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTypography.meta(AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _busy ? 'Asking Health…' : (_connected ? 'Sync today' : 'Connect Apple Health'),
            onPressed: _busy ? null : _handleConnect,
          ),
        ],
      ),
    );
  }
}
