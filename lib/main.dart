// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';

import 'backend/bloc/admin_auth_bloc.dart';
import 'backend/bloc/signup_request_bloc.dart';
import 'backend/controllers/admin_controller.dart';
import 'backend/controllers/signup_request_controller.dart';
import 'backend/services/firebase_platform_service.dart';
import 'firebase_options.dart';
import 'frontend/screens/admin_dashboard/landing_page/admin_dashboard_landing_page.dart';
import 'frontend/screens/login/landing_page/admin_login_landing_page.dart';
import 'shared/localization/app_localizations.dart';
import 'shared/localization/language_bloc.dart';
import 'shared/utils/colors.dart';
import 'shared/utils/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    ErrorHandler.logInfo('Starting Longeviva Admin App...');
    ErrorHandler.logInfo('Platform: ${defaultTargetPlatform.name}');

    // Show platform warning if applicable
    if (!FirebasePlatformService.isProductionReady) {
      final warning = FirebasePlatformService.platformWarning;
      if (warning != null) {
        ErrorHandler.logWarning(warning);
      }
    }

    // Initialize Firebase with platform-specific configuration
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Apply platform-specific Firebase configuration
    await FirebasePlatformService.initializeFirebaseForPlatform();

    ErrorHandler.logInfo('Firebase initialized successfully');

    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<AdminAuthBloc>(
            create: (context) => AdminAuthBloc(
              adminController: AdminController(),
            )..add(CheckAdminAuthStatus()),
          ),
          BlocProvider<LanguageBloc>(
            create: (context) => LanguageBloc()..add(const LanguageStarted()),
          ),
          BlocProvider<SignupRequestBloc>(
            create: (context) => SignupRequestBloc(
              controller: SignupRequestController(),
            ),
          ),
        ],
        child: const LongevivaAdminApp(),
      ),
    );
  } catch (e, stackTrace) {
    ErrorHandler.logError('Failed to start application', e);

    // Show error dialog if possible
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: CustomColors.rossoSimone,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Application Failed to Start',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.verdeAbisso,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Error: ${e.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CustomColors.rossoSimone,
                    ),
                  ),
                ),
                if (FirebasePlatformService.hasFirebaseLimitations) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          FirebasePlatformService.platformWarning ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Try to restart the app
                    main();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.verdeAbisso,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LongevivaAdminApp extends StatelessWidget {
  const LongevivaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, languageState) {
        return MaterialApp(
          title: 'Longeviva Admin',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: CustomColors.verdeAbisso),
            useMaterial3: true,
            fontFamily: 'Montserrat',
          ),
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
          home: const AdminAuthWrapper(),
          routes: {
            '/admin_login': (context) => const AdminLoginLandingPage(),
            '/admin_dashboard': (context) => const AdminDashboardLandingPage(),
          },
        );
      },
    );
  }
}

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminAuthBloc, AdminAuthState>(
      listener: (context, state) {
        // Handle side effects in listener, not in builder
        if (state is AdminAuthAuthenticated && FirebasePlatformService.hasFirebaseLimitations) {
          // Use post frame callback to avoid build-time side effects
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    FirebasePlatformService.platformWarning ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          });
        }
      },
      builder: (context, state) {
        if (state is AdminAuthLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: CustomColors.verdeAbisso,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  if (FirebasePlatformService.hasFirebaseLimitations) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Platform: ${defaultTargetPlatform.name}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        } else if (state is AdminAuthAuthenticated) {
          // Trigger signup requests fetch when authenticated
          context.read<SignupRequestBloc>().add(FetchAllSignupRequests());
          return const AdminDashboardLandingPage();
        } else {
          // For unauthenticated or any other state, show login
          return const AdminLoginLandingPage();
        }
      },
    );
  }
}