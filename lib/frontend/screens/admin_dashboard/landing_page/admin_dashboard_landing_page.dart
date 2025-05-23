// lib/frontend/screens/admin_dashboard/landing_page/admin_dashboard_landing_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/models/admin_model.dart';
import '../../../../shared/utils/error_handler.dart';
import '../view_model/admin_dashboard_large_screen_view_model.dart';
import '../view_model/admin_dashboard_small_screen_view_model.dart';

class AdminDashboardLandingPage extends StatefulWidget {
  final Admin admin;

  const AdminDashboardLandingPage({
    super.key,
    required this.admin,
  });

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
    ErrorHandler.logDebug('AdminDashboardLandingPage: Building for admin: ${widget.admin.email}');

    return BlocListener<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      listener: (context, state) {
        // Handle logout or auth failures
        if (state is AuthUnauthenticated || state is AuthFailure) {
          ErrorHandler.logDebug('Dashboard: User logged out, returning to login');
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth <= _smallScreenBreakpoint;

          if (isSmallScreen) {
            return AdminDashboardSmallScreenViewModel(
              admin: widget.admin,
              selectedIndex: _selectedIndex,
              onItemTapped: _navigateToPage,
              pageController: _pageController,
              pageTitle: _getPageTitle(_selectedIndex),
            );
          } else {
            return AdminDashboardLargeScreenViewModel(
              admin: widget.admin,
              selectedIndex: _selectedIndex,
              onItemTapped: _navigateToPage,
              pageController: _pageController,
              pageTitle: _getPageTitle(_selectedIndex),
            );
          }
        },
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Signup Requests';
      case 2:
        return 'User Management';
      default:
        return 'Dashboard';
    }
  }
}