// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'backend/bloc/admin_auth_bloc.dart';
import 'backend/bloc/admin_bloc.dart';
import 'backend/bloc/ritual_bloc.dart';
import 'backend/bloc/platform_analytics_bloc.dart';
import 'backend/bloc/doctors_bloc.dart';
import 'backend/bloc/patients_bloc.dart';
import 'backend/bloc/signup_request_bloc.dart';
import 'backend/controllers/admin_controller.dart';
import 'backend/controllers/signup_request_controller.dart';
import 'backend/services/unified_auth_service.dart';
import 'firebase_options.dart';
import 'frontend/auth/auth_wrapper.dart';
import 'frontend/screens/login/landing_page/admin_login_landing_page.dart';
import 'shared/localization/app_localizations.dart';
import 'shared/localization/language_bloc.dart';
import 'shared/utils/colors.dart';
import 'shared/utils/error_handler.dart';
import 'shared/config/environment_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    ErrorHandler.logInfo('🚀 Starting Longeviva Admin App...');
    ErrorHandler.logInfo('📱 Platform: ${defaultTargetPlatform.name}');
    ErrorHandler.logInfo('🔍 Build Mode: ${kDebugMode ? "DEBUG" : "RELEASE"}');

    // ========================================
    // STEP 1: Carica il file .env (solo in locale)
    // ========================================
    try {
      await dotenv.load(fileName: ".env");
      ErrorHandler.logInfo('✅ File .env caricato');
    } catch (e) {
      ErrorHandler.logInfo('⚠️ File .env non trovato (normale in produzione): $e');
      // In produzione il file .env non esiste, ed è normale
    }

    // ========================================
    // STEP 2: Inizializza la configurazione ambiente
    // ========================================
    await EnvironmentConfig().initialize();

    // ========================================
    // STEP 3: Inizializza Firebase
    // ========================================
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    ErrorHandler.logInfo('🔥 Firebase initialized successfully');

    // ========================================
    // STEP 4: Configura Firestore con il database corretto
    // ========================================
    EnvironmentConfig().configureFirestore();
    ErrorHandler.logInfo(
        '✅ Firestore configurato per ambiente: ${EnvironmentConfig().isDevelopment ? "SVILUPPO 🔧" : "PRODUZIONE 🚀"}'
    );
    ErrorHandler.logInfo('   Database ID: ${EnvironmentConfig().databaseId}');

    runApp(const LongevivaAdminApp());

  } catch (e, stackTrace) {
    ErrorHandler.logError('❌ Failed to start application', e);

    // Show error screen
    runApp(
      MaterialApp(
        home: AppErrorScreen(error: e.toString()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LongevivaAdminApp extends StatelessWidget {
  const LongevivaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Simplified Authentication BLoC
        BlocProvider<SimpleAdminAuthBloc>(
          create: (context) => SimpleAdminAuthBloc(),
        ),

        // Language BLoC
        BlocProvider<LanguageBloc>(
          create: (context) => LanguageBloc()..add(const LanguageStarted()),
        ),

        // Signup Request BLoC
        BlocProvider<SignupRequestBloc>(
          create: (context) => SignupRequestBloc(
            controller: SignupRequestController(),
          ),
        ),

        // Admin Operations BLoC
        BlocProvider<AdminOperationsBloc>(
          create: (context) => AdminOperationsBloc(
            adminController: AdminController(),
          ),
        ),

        // Ritual BLoC
        BlocProvider<RitualBloc>(
          create: (context) => RitualBloc(),
        ),

        // Platform Analytics BLoC
        BlocProvider<PlatformAnalyticsBloc>(
          create: (context) => PlatformAnalyticsBloc(),
        ),

        // Doctors BLoC
        BlocProvider<DoctorsBloc>(
          create: (context) => DoctorsBloc(),
        ),

        // Patients BLoC
        BlocProvider<PatientsBloc>(
          create: (context) => PatientsBloc(),
        ),
      ],
      child: BlocBuilder<LanguageBloc, LanguageState>(
        builder: (context, languageState) {
          return MaterialApp(
            title: 'Longeviva Admin',
            debugShowCheckedModeBanner: false,

            // Theme
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: CustomColors.verdeAbisso,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Montserrat',

              // Input decoration theme
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: CustomColors.verdeAbisso,
                    width: 2,
                  ),
                ),
              ),

              // Button themes
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.verdeAbisso,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Localization
            locale: languageState.locale,
            supportedLocales: languageState.supportedLanguages
                .map((lang) => Locale(lang.code))
                .toList(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Home screen
            home: const SimpleAuthWrapper(),

            // Routes
            routes: {
              '/login': (context) => const SimpleAdminLoginScreen(),
              '/dashboard': (context) => const SimpleAuthWrapper(),
            },
          );
        },
      ),
    );
  }
}

// Error screen for startup failures
class AppErrorScreen extends StatelessWidget {
  final String error;

  const AppErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.perla,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CustomColors.rossoSimone.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: CustomColors.rossoSimone,
                ),
              ),

              const SizedBox(height: 24),

              // Error title
              const Text(
                'Application Error',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),

              const SizedBox(height: 16),

              // Error message
              Text(
                'The application failed to start. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),

              const SizedBox(height: 24),

              // Error details (collapsed by default)
              ExpansionTile(
                title: const Text(
                  'Technical Details',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Retry button
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.verdeAbisso,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}