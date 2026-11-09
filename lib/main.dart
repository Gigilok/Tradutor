import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/setup_screen.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();

  if (AppConfig.isConfigured) {
    await SupabaseInit.ensureInitialized();
  }
  await state.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
      ],
      child: const PonteApp(),
    ),
  );
}

/// Inicializa o Supabase apenas quando as credenciais estão preenchidas.
class SupabaseInit {
  static bool _done = false;

  static Future<void> ensureInitialized() async {
    if (_done) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _done = true;
  }
}

class PonteApp extends StatelessWidget {
  const PonteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF34D399), // verde-menta
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF121417),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1D21),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E2227),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E2227),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 50),
            side: BorderSide(color: scheme.primary.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      builder: (context, child) {
        // Corrige o texto do sistema para não estourar em fontes grandes.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.4,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppEntry(),
    );
  }
}

/// Decide a primeira tela: instruções (sem Supabase configurado),
/// entrada na sala ou direto para a conversa.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!AppConfig.isConfigured) {
      return const SetupScreen();
    }
    return state.isLoggedIn ? const HomeScreen() : const JoinScreen();
  }
}
