import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/routing/app_router.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_theme.dart';

class FitMateApp extends ConsumerStatefulWidget {
  const FitMateApp({super.key});

  @override
  ConsumerState<FitMateApp> createState() => _FitMateAppState();
}

class _FitMateAppState extends ConsumerState<FitMateApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(syncEngineProvider).start());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return CupertinoApp.router(
      title: 'FitMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(MediaQuery.platformBrightnessOf(context)),
      routerConfig: router,
    );
  }
}
