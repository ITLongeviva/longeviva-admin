// lib/shared/services/firebase_platform_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/utils/error_handler.dart';

class FirebasePlatformService {
  static Future<void> initializeFirebaseForPlatform() async {
    try {
      ErrorHandler.logDebug('Initializing Firebase for platform: ${defaultTargetPlatform.name}');

      // Platform-specific Firebase initialization
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          await _initializeForWindows();
          break;
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          await _initializeForNative();
          break;
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          await _initializeForWeb(); // Use web config as fallback
          break;
      }

      // Configure authentication persistence based on platform
      await _configurePlatformSpecificAuth();

      ErrorHandler.logInfo('Firebase initialized successfully for ${defaultTargetPlatform.name}');

    } catch (e) {
      ErrorHandler.logError('Failed to initialize Firebase for platform', e);
      throw AppException(
        'Firebase initialization failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  static Future<void> _initializeForWindows() async {
    try {
      // For Windows, we need to be more explicit about configuration
      await Firebase.initializeApp();

      // Force refresh authentication state on Windows
      final auth = FirebaseAuth.instance;

      // Set up authentication state listener with retry for Windows
      auth.authStateChanges().listen((User? user) {
        if (user != null) {
          ErrorHandler.logDebug('Windows: User authenticated: ${user.email}');
          // Force token refresh for Windows to ensure custom claims are loaded
          _forceTokenRefreshForWindows(user);
        } else {
          ErrorHandler.logDebug('Windows: User signed out');
        }
      });

    } catch (e) {
      ErrorHandler.logError('Windows Firebase initialization failed', e);
      rethrow;
    }
  }

  static Future<void> _initializeForNative() async {
    // Standard initialization for native platforms
    await Firebase.initializeApp();
  }

  static Future<void> _initializeForWeb() async {
    try {
      await Firebase.initializeApp();

      // Configure persistence for web
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

    } catch (e) {
      ErrorHandler.logError('Web Firebase initialization failed', e);
      rethrow;
    }
  }

  static Future<void> _configurePlatformSpecificAuth() async {
    final auth = FirebaseAuth.instance;

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      // Windows-specific configuration
        ErrorHandler.logDebug('Configuring Windows-specific auth settings');

        // Set up periodic token refresh for Windows
        _setupPeriodicTokenRefresh();
        break;

      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      // Native platforms handle persistence automatically
        ErrorHandler.logDebug('Using default native auth configuration');
        break;

      default:
      // Web and other platforms
        try {
          await auth.setPersistence(Persistence.LOCAL);
          ErrorHandler.logDebug('Set web persistence to LOCAL');
        } catch (e) {
          ErrorHandler.logWarning('Could not set persistence: $e');
        }
        break;
    }
  }

  static Future<void> _forceTokenRefreshForWindows(User user) async {
    try {
      // Wait a bit before forcing refresh to allow backend propagation
      await Future.delayed(const Duration(seconds: 2));

      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? {};

      ErrorHandler.logDebug('Windows: Forced token refresh completed. Claims: ${claims.keys.toList()}');

    } catch (e) {
      ErrorHandler.logWarning('Windows: Failed to force token refresh: $e');
    }
  }

  static void _setupPeriodicTokenRefresh() {
    // Set up periodic token refresh for Windows to handle custom claims
    Stream.periodic(const Duration(minutes: 5)).listen((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _forceTokenRefreshForWindows(user);
      }
    });
  }

  /// Check if the current platform has known Firebase limitations
  static bool get hasFirebaseLimitations {
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Get platform-specific warning message
  static String? get platformWarning {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Note: Firebase on Windows is intended for development only. '
          'Authentication may be less reliable than on other platforms.';
    }
    return null;
  }

  /// Validate if platform is suitable for production
  static bool get isProductionReady {
    return defaultTargetPlatform != TargetPlatform.windows;
  }
}

// Extension to help with platform-specific authentication handling
extension PlatformAuthExtension on FirebaseAuth {
  /// Platform-aware sign in with enhanced error handling
  Future<UserCredential> signInWithEmailPasswordPlatformAware({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Platform-specific post-login handling
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // For Windows, ensure we wait for custom claims
        if (userCredential.user != null) {
          await Future.delayed(const Duration(seconds: 1));
          await userCredential.user!.getIdTokenResult(true);
        }
      }

      return userCredential;
    } catch (e) {
      ErrorHandler.logError('Platform-aware sign in failed', e);
      rethrow;
    }
  }
}