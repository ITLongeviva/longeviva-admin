import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend/bloc/admin_auth_bloc.dart';
import 'backend/bloc/signup_request_bloc.dart';
import 'backend/controllers/admin_controller.dart';
import 'backend/controllers/signup_request_controller.dart';
import 'firebase_options.dart';
import 'frontend/screens/admin_dashboard/landing_page/admin_dashboard_landing_page.dart';
import 'frontend/screens/login/landing_page/admin_login_landing_page.dart';
import 'shared/localization/app_localizations.dart';
import 'shared/localization/language_bloc.dart';
import 'shared/utils/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    return BlocBuilder<AdminAuthBloc, AdminAuthState>(
      builder: (context, state) {
        if (state is AdminAuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: CustomColors.verdeAbisso,
              ),
            ),
          );
        } else if (state is AdminAuthAuthenticated) {
          // When navigating to dashboard, also trigger signup requests fetch
          context.read<SignupRequestBloc>().add(FetchAllSignupRequests());
          return const AdminDashboardLandingPage();
        } else {
          return const AdminLoginLandingPage();
        }
      },
    );
  }
}