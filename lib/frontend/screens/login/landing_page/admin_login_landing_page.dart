// lib/frontend/screens/login/simple_admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:email_validator/email_validator.dart';
import 'package:longeviva_admin_v1/shared/utils/context_extensions.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../shared/utils/colors.dart';

class SimpleAdminLoginScreen extends StatefulWidget {
  const SimpleAdminLoginScreen({super.key});

  @override
  State<SimpleAdminLoginScreen> createState() => _SimpleAdminLoginScreenState();
}

class _SimpleAdminLoginScreenState extends State<SimpleAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SimpleAdminAuthBloc>().add(
        LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        ),
      );
    }
  }

  void _showPasswordResetDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your admin email address to receive password reset instructions.',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resetEmailController.text.isNotEmpty &&
                  EmailValidator.validate(resetEmailController.text)) {
                Navigator.of(dialogContext).pop();
                context.read<SimpleAdminAuthBloc>().add(
                  PasswordResetRequested(resetEmailController.text.trim()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.verdeAbisso,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          // Navigate to dashboard
          Navigator.of(context).pushReplacementNamed('/admin_dashboard');
        } else if (state is AuthFailure) {
          // Show error message
          context.showErrorAlert(state.message);
        } else if (state is PasswordResetSent) {
          context.showSuccessAlert(
            'Password reset email sent to ${state.email}. Please check your inbox.',
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CustomColors.verdeAbisso.withOpacity(0.8),
                CustomColors.verdeMare.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo and Title
                          _buildHeader(),

                          const SizedBox(height: 32),

                          // Login Form
                          _buildLoginForm(),

                          const SizedBox(height: 24),

                          // Login Button
                          _buildLoginButton(),

                          const SizedBox(height: 16),

                          // Forgot Password
                          _buildForgotPasswordButton(),

                          const SizedBox(height: 24),

                          // Footer
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: CustomColors.verdeAbisso.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            size: 40,
            color: CustomColors.verdeAbisso,
          ),
        ),

        const SizedBox(height: 16),

        // Title
        const Text(
          'Admin Portal',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: CustomColors.verdeAbisso,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Longeviva Healthcare Platform',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your admin email',
              prefixIcon: const Icon(Icons.email_outlined),
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
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Remember Me Checkbox
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: CustomColors.verdeAbisso,
              ),
              const Text(
                'Remember me for 7 days',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return BlocBuilder<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.verdeAbisso,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Sign In',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _showPasswordResetDialog,
      child: const Text(
        'Forgot your password?',
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: CustomColors.verdeAbisso,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),

        const SizedBox(height: 16),

        const Text(
          '© 2025 Longeviva s.r.l',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                // TODO: Show terms of service
              },
              child: const Text(
                'Terms',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const Text(' • ', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () {
                // TODO: Show privacy policy
              },
              child: const Text(
                'Privacy',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}