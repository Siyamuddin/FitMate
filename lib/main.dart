import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/app.dart';
import 'package:fitmate/core/networking/app_env.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  if (!AppEnv.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await SupabaseProvider.initialize();
  runApp(const ProviderScope(child: FitMateApp()));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Add SUPABASE_URL and SUPABASE_ANON_KEY to .env or dart-define, then restart.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
