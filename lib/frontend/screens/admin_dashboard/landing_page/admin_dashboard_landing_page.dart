import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:longeviva_admin_v1/shared/utils/context_extensions.dart';
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
    ErrorHandler.logDebug('AdminDashboardLandingPage: Building dashboard (Emergency Fix)');

    return BlocProvider<AdminOperationsBloc>(
      create: (context) => AdminOperationsBloc(
        adminController: AdminController(),
      ),
      child: BlocBuilder<AdminAuthBloc, AdminAuthState>(
        builder: (context, state) {
          ErrorHandler.logDebug('AdminDashboardLandingPage: State = ${state.runtimeType}');

          // Get the admin - if we're here, we should have one
          final admin = (state is AdminAuthAuthenticated) ? state.admin : null;

          if (admin != null) {
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
                }
            );
          } else {
            ErrorHandler.logDebug('AdminDashboardLandingPage: No admin found');
            context.showErrorAlert('No admin found');
            return AdminLoginLandingPage();
          }
        },
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