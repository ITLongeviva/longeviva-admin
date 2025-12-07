import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../view_model/admin_dashboard_home_large_screen_view_model.dart';
import '../view_model/admin_dashboard_home_small_screen_view_model.dart';

class AdminDashboardHome extends StatelessWidget {
  const AdminDashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Load initial data
    context.read<AdminOperationsBloc>().add(FetchAllUsers());

    // SignupRequestBloc is already available from main.dart
    context.read<SignupRequestBloc>().add(FetchAllSignupRequests());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth <= 1000;

        if (isSmallScreen) {
          return const AdminDashboardHomeSmallScreenViewModel();
        } else {
          return const AdminDashboardHomeLargeScreenViewModel();
        }
      },
    );
  }
}