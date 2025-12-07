// lib/frontend/auth/simple_auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../backend/bloc/admin_auth_bloc.dart';
import '../../backend/models/admin_model.dart';
import '../../shared/utils/colors.dart';
import '../../shared/utils/error_handler.dart';
import '../screens/login/landing_page/admin_login_landing_page.dart';
import '../screens/admin_dashboard/landing_page/admin_dashboard_landing_page.dart';

class SimpleAuthWrapper extends StatefulWidget {
  const SimpleAuthWrapper({super.key});

  @override
  State<SimpleAuthWrapper> createState() => _SimpleAuthWrapperState();
}

class _SimpleAuthWrapperState extends State<SimpleAuthWrapper> {
  bool _hasCheckedAuth = false;

  @override
  void initState() {
    super.initState();
    // Check auth status after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasCheckedAuth) {
        _hasCheckedAuth = true;
        context.read<SimpleAdminAuthBloc>().add(CheckAuthRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      listener: (context, state) {
        // Handle any side effects here
        if (state is AuthFailure) {
          ErrorHandler.logError('Auth failure in wrapper', state.message);
        }
      },
      builder: (context, state) {
        ErrorHandler.logDebug('SimpleAuthWrapper state: ${state.runtimeType}');

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildScreen(state),
        );
      },
    );
  }

  Widget _buildScreen(SimpleAdminAuthState state) {
    switch (state.runtimeType) {
      case AuthInitial:
      case AuthLoading:
        return _buildLoadingScreen();

      case AuthSuccess:
        final successState = state as AuthSuccess;
        return AdminDashboardWrapper(admin: successState.admin);

      case AuthUnauthenticated:
      case AuthFailure:
        return const SimpleAdminLoginScreen();

      case PasswordResetSent:
      // Stay on login screen after password reset
        return const SimpleAdminLoginScreen();

      default:
        return const SimpleAdminLoginScreen();
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),

              SizedBox(height: 24),

              // Loading text
              Text(
                'Checking authentication...',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'Please wait',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Wrapper for the admin dashboard that handles the admin object
class AdminDashboardWrapper extends StatelessWidget {
  final Admin admin;

  const AdminDashboardWrapper({
    super.key,
    required this.admin,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      listener: (context, state) {
        // Handle logout or auth failures
        if (state is AuthUnauthenticated || state is AuthFailure) {
          // Navigate back to login
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      },
      child: AdminDashboardLandingPage(admin: admin),
    );
  }
}