import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../view_model/user_management_large_screen_view_model.dart';
import '../view_model/user_management_small_screen_view_model.dart';

class UsersManagementPageLandingPage extends StatelessWidget {
  const UsersManagementPageLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Load users when the page is opened
    context.read<AdminOperationsBloc>().add(FetchAllUsers());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Define responsive breakpoint
        final isSmallScreen = constraints.maxWidth <= 1000;

        if (isSmallScreen) {
          return const UserManagementSmallScreenViewModel();
        } else {
          return const UserManagementLargeScreenViewModel();
        }
      },
    );
  }
}