// lib/shared/utils/secure_password_generator.dart
import 'dart:math';

class SecurePasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _specialChars = '@\$!%*?&';
  static const String _allChars = _lowercase + _uppercase + _numbers + _specialChars;

  /// Generate a secure temporary password that meets all validation requirements
  /// - At least 8 characters long
  /// - Contains at least one lowercase letter
  /// - Contains at least one uppercase letter
  /// - Contains at least one number
  /// - Contains at least one special character (@$!%*?&)
  static String generateSecureTemporaryPassword({int length = 12, int maxAttempts = 10}) {
    if (length < 8) {
      throw ArgumentError('Password length must be at least 8 characters');
    }

    final random = Random.secure();

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Create a list to hold all password characters
      final passwordChars = <String>[];

      // STEP 1: Add required characters (one of each type)
      passwordChars.add(_lowercase[random.nextInt(_lowercase.length)]);
      passwordChars.add(_uppercase[random.nextInt(_uppercase.length)]);
      passwordChars.add(_numbers[random.nextInt(_numbers.length)]);
      passwordChars.add(_specialChars[random.nextInt(_specialChars.length)]);

      // STEP 2: Fill remaining positions with random characters from all sets
      for (int i = 4; i < length; i++) {
        passwordChars.add(_allChars[random.nextInt(_allChars.length)]);
      }

      // STEP 3: Shuffle the entire password to avoid predictable patterns
      for (int i = passwordChars.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = passwordChars[i];
        passwordChars[i] = passwordChars[j];
        passwordChars[j] = temp;
      }

      final finalPassword = passwordChars.join('');

      // STEP 4: Validate the generated password
      final validation = validateStrongPassword(finalPassword);
      if (validation.isValid) {
        // Double-check each requirement explicitly
        if (_hasLowercase(finalPassword) &&
            _hasUppercase(finalPassword) &&
            _hasNumber(finalPassword) &&
            _hasSpecialChar(finalPassword) &&
            finalPassword.length >= 8) {
          return finalPassword;
        }
      }

      // If validation failed, try again
      print('Password generation attempt ${attempt + 1} failed validation, retrying...');
    }

    // If we couldn't generate a valid password after maxAttempts, throw an error
    throw StateError('Failed to generate a valid password after $maxAttempts attempts');
  }

  // Helper methods for explicit validation
  static bool _hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  static bool _hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  static bool _hasNumber(String password) => RegExp(r'\d').hasMatch(password);
  static bool _hasSpecialChar(String password) => RegExp(r'[@$!%*?&]').hasMatch(password);

  /// Validate password strength according to security requirements
  static ValidationResult validateStrongPassword(String? value, {bool isRequired = true}) {
    if (value == null || value.isEmpty) {
      return ValidationResult(
        isValid: !isRequired,
        errorMessage: isRequired ? 'Password is required' : null,
      );
    }

    if (value.length < 8) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must be at least 8 characters long',
      );
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must contain at least one lowercase letter',
      );
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must contain at least one uppercase letter',
      );
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must contain at least one number',
      );
    }

    if (!RegExp(r'[@$!%*?&]').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must contain at least one special character (@\$!%*?&)',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Generate multiple secure passwords for testing/comparison
  static List<String> generateMultiplePasswords({int count = 5, int length = 12}) {
    final passwords = <String>[];
    for (int i = 0; i < count; i++) {
      passwords.add(generateSecureTemporaryPassword(length: length));
    }
    return passwords;
  }

  /// Get password strength score (0-100)
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Length score (up to 25 points)
    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 5;

    // Character variety (up to 60 points)
    if (RegExp(r'[a-z]').hasMatch(password)) score += 15;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;
    if (RegExp(r'\d').hasMatch(password)) score += 15;
    if (RegExp(r'[@$!%*?&]').hasMatch(password)) score += 15;

    // Additional complexity (up to 15 points)
    if (RegExp(r'[a-z].*[a-z]').hasMatch(password)) score += 3; // Multiple lowercase
    if (RegExp(r'[A-Z].*[A-Z]').hasMatch(password)) score += 3; // Multiple uppercase
    if (RegExp(r'\d.*\d').hasMatch(password)) score += 3; // Multiple numbers
    if (RegExp(r'[@$!%*?&].*[@$!%*?&]').hasMatch(password)) score += 3; // Multiple special
    if (password.length >= 20) score += 3; // Very long password

    return score.clamp(0, 100);
  }

  /// Get password strength description
  static String getPasswordStrengthDescription(String password) {
    final strength = getPasswordStrength(password);

    if (strength >= 90) return 'Excellent';
    if (strength >= 75) return 'Very Strong';
    if (strength >= 60) return 'Strong';
    if (strength >= 40) return 'Moderate';
    if (strength >= 20) return 'Weak';
    return 'Very Weak';
  }

  /// Unified password validation for UI consistency
  /// Returns a Map with validation results and user-friendly messages
  static Map<String, dynamic> validatePasswordForUI(String password) {
    final validation = validateStrongPassword(password);
    final strength = getPasswordStrength(password);
    final description = getPasswordStrengthDescription(password);

    return {
      'isValid': validation.isValid,
      'errorMessage': validation.errorMessage,
      'strength': strength,
      'strengthDescription': description,
      'hasLowercase': _hasLowercase(password),
      'hasUppercase': _hasUppercase(password),
      'hasNumber': _hasNumber(password),
      'hasSpecialChar': _hasSpecialChar(password),
      'hasMinLength': password.length >= 8,
      'requirements': {
        'lowercase': _hasLowercase(password),
        'uppercase': _hasUppercase(password),
        'number': _hasNumber(password),
        'specialChar': _hasSpecialChar(password),
        'minLength': password.length >= 8,
      }
    };
  }

  /// Test the password generator to ensure it always produces valid passwords
  static void testPasswordGeneration({int testCount = 20}) {
    print('🧪 Testing Secure Password Generator...');

    int successCount = 0;
    int failureCount = 0;

    for (int i = 0; i < testCount; i++) {
      try {
        final password = generateSecureTemporaryPassword(length: 12);
        final validation = validatePasswordForUI(password);

        if (validation['isValid']) {
          successCount++;
          print('✅ Test ${i + 1}: $password - Valid (${validation['strengthDescription']})');

          // Detailed validation check
          final reqs = validation['requirements'];
          if (!reqs['lowercase'] || !reqs['uppercase'] || !reqs['number'] ||
              !reqs['specialChar'] || !reqs['minLength']) {
            print('❌ CRITICAL: Password passed validation but missing requirements!');
            print('   Lowercase: ${reqs['lowercase']}');
            print('   Uppercase: ${reqs['uppercase']}');
            print('   Number: ${reqs['number']}');
            print('   Special: ${reqs['specialChar']}');
            print('   MinLength: ${reqs['minLength']}');
            failureCount++;
          }
        } else {
          failureCount++;
          print('❌ Test ${i + 1}: $password - Invalid: ${validation['errorMessage']}');
        }
      } catch (e) {
        failureCount++;
        print('❌ Test ${i + 1}: Exception - $e');
      }
    }

    print('\n📊 Test Results:');
    print('✅ Successful: $successCount/$testCount');
    print('❌ Failed: $failureCount/$testCount');
    print('🎯 Success Rate: ${(successCount / testCount * 100).toStringAsFixed(1)}%');

    if (failureCount > 0) {
      throw StateError('Password generator failed $failureCount/$testCount tests!');
    }
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errorMessage: $errorMessage)';
  }
}