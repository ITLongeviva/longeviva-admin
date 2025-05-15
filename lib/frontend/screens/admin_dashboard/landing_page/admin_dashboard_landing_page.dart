import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/controllers/admin_controller.dart';
import '../view_model/admin_dashboard_large_screen_view_model.dart';
import '../view_model/admin_dashboard_small_screen_view_model.dart';
import '../../../../shared/widgets/custom_progress_indicator.dart';

class AdminDashboardLandingPage extends StatefulWidget {
  const AdminDashboardLandingPage({super.key});

  @override
  State<AdminDashboardLandingPage> createState() => _AdminDashboardLandingPageState();
}

class _AdminDashboardLandingPageState extends State<AdminDashboardLandingPage> {
  int _selectedIndex = 0;
  bool _isRedirecting = false;
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
    return MultiBlocProvider(
      providers: [
        // Remove AdminAuthBloc from here - it's already provided in main.dart
        BlocProvider<AdminOperationsBloc>(
          create: (context) => AdminOperationsBloc(
            adminController: AdminController(),
          ),
        ),
      ],
      child: BlocConsumer<AdminAuthBloc, AdminAuthState>(
        listener: (context, state) {
          if (state is AdminAuthUnauthenticated && !_isRedirecting) {
            _isRedirecting = true;
            Future.microtask(() {
              Navigator.of(context).pushReplacementNamed('/admin_login');
              _isRedirecting = false;
            });
          }
        },
        builder: (context, state) {
          // Remove the AdminAuthInitial check since it's handled in main.dart
          if (state is AdminAuthLoading) {
            return const Scaffold(
              body: Center(
                child: CustomProgressIndicator(
                  message: "Loading admin dashboard...",
                ),
              ),
            );
          }

          if (state is AdminAuthAuthenticated) {
            return LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth <= _smallScreenBreakpoint;

                  if (isSmallScreen) {
                    return AdminDashboardSmallScreenViewModel(
                      admin: state.admin,
                      selectedIndex: _selectedIndex,
                      onItemTapped: _navigateToPage,
                      pageController: _pageController,
                      pageTitle: _getPageTitle(_selectedIndex),
                    );
                  } else {
                    return AdminDashboardLargeScreenViewModel(
                      admin: state.admin,
                      selectedIndex: _selectedIndex,
                      onItemTapped: _navigateToPage,
                      pageController: _pageController,
                      pageTitle: _getPageTitle(_selectedIndex),
                    );
                  }
                }
            );
          }

          return const Scaffold(
            body: Center(
              child: CustomProgressIndicator(
                message: "Preparing dashboard...",
              ),
            ),
          );
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