import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'context_extensions.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final String? translationKey;
  final Map<String, String>? translationArgs;

  AppException(
      this.message, {
        this.code,
        this.originalError,
        this.translationKey,
        this.translationArgs,
      });

  @override
  String toString() {
    if (originalError != null) {
      return 'AppException: $message (Original error: $originalError)';
    }
    return 'AppException: $message';
  }
}

class ErrorHandler {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // Error Message Handling
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      return _handleFirebaseError(error);
    } else if (error is AppException) {
      return error.message;
    } else {
      return 'An unexpected error occurred';
    }
  }

  static String _handleFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission to access this resource';
      case 'not-found':
        return 'The requested resource was not found';
      case 'already-exists':
        return 'The resource already exists';
      case 'failed-precondition':
        return 'Operation failed due to a precondition check';
      case 'unavailable':
        return 'Service is currently unavailable';
      case 'unauthenticated':
        return 'User is not authenticated';
      case 'cancelled':
        return 'Operation was cancelled';
      case 'deadline-exceeded':
        return 'Operation timed out';
      case 'invalid-argument':
        return 'Invalid data provided';
      case 'resource-exhausted':
        return 'Resource quota exceeded';
      case 'aborted':
        return 'Operation was aborted';
      case 'out-of-range':
        return 'Operation was attempted past valid range';
      case 'unimplemented':
        return 'Operation is not implemented';
      case 'internal':
        return 'Internal error occurred';
      case 'data-loss':
        return 'Unrecoverable data loss or corruption';
      default:
        return error.message ?? 'An unknown error occurred';
    }
  }

  // New method specifically for permission errors
  static void showPermissionErrorAlert(BuildContext context, String message) {
    context.showForbiddenActionAlert(message);
  }

  // Logging Functions
  static void logDebug(String message) {
    _logger.d(message);
  }

  static void logInfo(String message) {
    _logger.i(message);
  }

  static void logWarning(String message) {
    _logger.w(message);
  }

  static void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    _logger.e(message);
  }

  // Error Dialog - Using existing dialog for more detailed messages that need longer visibility
  static Future<void> showErrorDialog(
      BuildContext context, {
        required String title,
        required String message,
        String? buttonText,
      }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText ?? 'OK'),
          ),
        ],
      ),
    );
  }

  // Network Error Check
  static bool isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'network-request-failed';
    }
    return false;
  }

  // Permission Error Check
  static bool isPermissionError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthorized';
    }
    return false;
  }
}