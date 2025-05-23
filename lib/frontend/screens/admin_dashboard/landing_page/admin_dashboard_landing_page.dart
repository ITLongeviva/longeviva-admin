// lib/frontend/screens/admin_dashboard/landing_page/admin_dashboard_landing_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/controllers/admin_controller.dart';
import '../../../../backend/models/admin_model.dart';
import '../../login/landing_page/admin_login_landing_page.dart';
import '../view_model/admin_dashboard_large_screen_view_model.dart';
import '../view_model/admin_dashboard_small_screen_view_model.dart';
import '../../../../shared/utils/error_handler.dart';

class AdminDashboardLandingPage extends StatefulWidget {
  const AdminDashboardLandingPage({super.key});

  @override
  State<AdminDashboardLandingPage> createState() => _AdminDashboardLandingPageState();
}

class _AdminDashboardLandingPageState extends State<AdminDashboardLandingPage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final double _smallScreenBreakpoint = 1100;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    ErrorHandler.logDebug('AdminDashboardLandingPage: Building dashboard');

    return BlocProvider<AdminOperationsBloc>(
      create: (context) => AdminOperationsBloc(
        adminController: AdminController(),
      ),
      child: BlocConsumer<AdminAuthBloc, AdminAuthState>(
        listener: (context, state) {
          // Handle state changes that require side effects
          if (state is AdminAuthUnauthenticated) {
            ErrorHandler.logDebug('AdminDashboardLandingPage: User unauthenticated, navigating to login');

            // Use post frame callback to avoid build-time navigation
            Future.microtask(() {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/admin_login');
              }
            });
          } else if (state is AdminAuthFailure) {
            ErrorHandler.logError('AdminDashboardLandingPage: Auth failure', state.error);

            // Use post frame callback to avoid build-time side effects
            Future.microtask(() {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Authentication error: ${state.error}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).pushReplacementNamed('/admin_login');
              }
            });
          }
        },
        builder: (context, state) {
          ErrorHandler.logDebug('AdminDashboardLandingPage: State = ${state.runtimeType}');

          // Handle different authentication states
          if (state is AdminAuthLoading) {
            return _buildLoadingScreen();
          }

          if (state is AdminAuthAuthenticated) {
            final admin = state.admin;
            ErrorHandler.logDebug('AdminDashboardLandingPage: Found admin: ${admin.email}');

            return LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth <= _smallScreenBreakpoint;

                if (isSmallScreen) {
                  return AdminDashboardSmallScreenViewModel(
                    admin: admin,
                    selectedIndex: _selectedIndex,
                    onItemTapped: _navigateToPage,
                    pageController: _pageController,
                    pageTitle: _getPageTitle(_selectedIndex),
                  );
                } else {
                  return AdminDashboardLargeScreenViewModel(
                    admin: admin,
                    selectedIndex: _selectedIndex,
                    onItemTapped: _navigateToPage,
                    pageController: _pageController,
                    pageTitle: _getPageTitle(_selectedIndex),
                  );
                }
              },
            );
          }

          // For any other state (including unauthenticated), show login
          // Don't show alerts here - let the listener handle navigation
          ErrorHandler.logDebug('AdminDashboardLandingPage: Showing login screen for state: ${state.runtimeType}');
          return const AdminLoginLandingPage();
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading Admin Dashboard...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Signup Requests';
      case 2:
        return 'User Management';
      default:
        return 'Admin Dashboard';
    }
  }
}