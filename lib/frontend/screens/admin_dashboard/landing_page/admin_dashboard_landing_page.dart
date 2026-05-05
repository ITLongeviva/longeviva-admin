import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/doctors_bloc.dart';
import '../../../../backend/bloc/patients_bloc.dart';
import '../../../../backend/bloc/platform_analytics_bloc.dart';
import '../../../../backend/bloc/ritual_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
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
  State<AdminDashboardLandingPage> createState() =>
      _AdminDashboardLandingPageState();
}

class _AdminDashboardLandingPageState
    extends State<AdminDashboardLandingPage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final double _smallScreenBreakpoint = 1100;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    // Prevent redundant navigation and double-dispatch from onPageChanged
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });

    _refreshTab(index);
  }

  /// Refreshes data for the target tab. Called on every navigation so the
  /// admin always sees current Firestore data, even with keepAlive pages.
  void _refreshTab(int index) {
    switch (index) {
      case 0:
        final adminBloc = context.read<AdminOperationsBloc>();
        if (adminBloc.state is! AdminOperationsInitial) {
          adminBloc.add(FetchAllUsers());
        }
        final signupBloc = context.read<SignupRequestBloc>();
        if (signupBloc.state is! SignupRequestInitial) {
          signupBloc.add(FetchAllSignupRequests());
        }
        break;
      case 3:
        context.read<RitualBloc>().add(LoadRitualAnalytics());
        break;
      case 4:
        context.read<PlatformAnalyticsBloc>().add(LoadPlatformAnalytics());
        break;
      case 5:
        context.read<DoctorsBloc>().add(LoadDoctors());
        break;
      case 6:
        context.read<PatientsBloc>().add(LoadPatients());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ErrorHandler.logDebug(
        'AdminDashboardLandingPage: Building for admin: ${widget.admin.email}');

    return BlocListener<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      listener: (context, state) {
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
      case 3:
        return 'Rituali';
      case 4:
        return 'Analytics Piattaforma';
      case 5:
        return 'Dottori';
      case 6:
        return 'Pazienti';
      default:
        return 'Dashboard';
    }
  }
}
