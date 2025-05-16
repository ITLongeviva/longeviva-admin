import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:email_validator/email_validator.dart';
import 'package:longeviva_admin_v1/shared/utils/context_extensions.dart';

import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/widgets/custom_progress_indicator.dart';

class AdminLoginForm extends StatefulWidget {
  const AdminLoginForm({super.key});

  @override
  State<AdminLoginForm> createState() => _AdminLoginFormState();
}

class _AdminLoginFormState extends State<AdminLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isEmailError = false;
  bool _isPasswordError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Clear previous error state
      setState(() {
        _errorMessage = null;
        _isEmailError = false;
        _isPasswordError = false;
      });

      context.read<AdminAuthBloc>().add(
        AdminLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        ),
      );
    }
  }

  // Add this method to show the forgot password dialog
  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();

    context.showAnimatedDialog(
      dialogBuilder: (dialogContext) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: CustomColors.verdeAbisso,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your admin email address. We\'ll send you a link to reset your password.',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Hide the dialog
              Navigator.of(dialogContext).pop();

              // Trigger password reset
              if (emailController.text.isNotEmpty) {
                context.read<AdminAuthBloc>().add(
                  AdminRequestPasswordReset(
                    email: emailController.text.trim(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.verdeMare,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminAuthBloc, AdminAuthState>(
      listener: (context, state) {
        print('Admin Auth state changed: $state');

        if (state is AdminPasswordResetSent) {
          context.showSuccessAlert(
            'Password reset link sent to ${state.email}. Please check your email.',
          );
        }
      },
      builder: (context, state) {
        if (state is AdminAuthFailure) {
          _errorMessage = state.error;

          final error = state.error.toLowerCase();
          _isEmailError = error.contains('email') || error.contains('not found');
          _isPasswordError = error.contains('password') || error.contains('invalid');

          if (!_isEmailError && !_isPasswordError) {
            _isEmailError = true;
            _isPasswordError = true;
          }
        }

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with admin title
              const Text(
                'Admin Login',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.biancoPuro,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Error message display
              if (_errorMessage != null && state is AdminAuthFailure)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: CustomColors.rossoSimone.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CustomColors.rossoSimone),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: CustomColors.rossoSimone,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            color: CustomColors.rossoSimone,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: CustomColors.rossoSimone,
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: CustomColors.biancoPuro,
                  labelText: 'Email',
                  labelStyle: TextStyle(
                      fontFamily: 'Montserrat', color: _isEmailError ? CustomColors.rossoSimone : null),
                  prefixIcon: Icon(Icons.email,
                      color: _isEmailError ? CustomColors.rossoSimone : CustomColors.verdeAbisso),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isEmailError ? CustomColors.rossoSimone : CustomColors.verdeAbisso, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _isEmailError ? CustomColors.rossoSimone : Colors.grey.shade400,
                    ),
                  ),
                ),
                onChanged: (_) {
                  // Clear error state when user starts typing
                  if (_isEmailError) {
                    setState(() {
                      _isEmailError = false;
                      if (!_isPasswordError) _errorMessage = null;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: CustomColors.biancoPuro,
                  labelText: 'Password',
                  labelStyle: TextStyle(
                      fontFamily: 'Montserrat', color: _isPasswordError ? CustomColors.rossoSimone : null),
                  prefixIcon: Icon(Icons.lock,
                      color: _isPasswordError ? CustomColors.rossoSimone : CustomColors.verdeAbisso),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: _isPasswordError ? CustomColors.rossoSimone : CustomColors.verdeAbisso,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isPasswordError ? CustomColors.rossoSimone : CustomColors.verdeAbisso,
                        width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _isPasswordError ? CustomColors.rossoSimone : Colors.grey.shade400,
                    ),
                  ),
                ),
                onChanged: (_) {
                  // Clear error state when user starts typing
                  if (_isPasswordError) {
                    setState(() {
                      _isPasswordError = false;
                      if (!_isEmailError) _errorMessage = null;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: CustomColors.biancoPuro,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 42),

              // Login button
              ElevatedButton(
                onPressed: state is AdminAuthLoading ? null : _submitForm, // Disable during loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.verdeMare,
                  foregroundColor: CustomColors.biancoPuro,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: state is AdminAuthLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CustomProgressIndicator(
                      size: 20,
                      color: CustomColors.biancoPuro,
                      message: "Logging in...",
                    ))
                    : const Text(
                  'Admin Login',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}