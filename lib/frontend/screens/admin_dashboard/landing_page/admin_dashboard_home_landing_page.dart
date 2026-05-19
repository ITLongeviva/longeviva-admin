import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../view_model/admin_dashboard_home_large_screen_view_model.dart';
import '../view_model/admin_dashboard_home_small_screen_view_model.dart';

class AdminDashboardHome extends StatefulWidget {
  const AdminDashboardHome({super.key});

  @override
  State<AdminDashboardHome> createState() => _AdminDashboardHomeState();
}

class _AdminDashboardHomeState extends State<AdminDashboardHome>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final adminBloc = context.read<AdminOperationsBloc>();
    if (adminBloc.state is AdminOperationsInitial) {
      adminBloc.add(FetchAllUsers());
    }
    final signupBloc = context.read<SignupRequestBloc>();
    if (signupBloc.state is SignupRequestInitial) {
      signupBloc.add(FetchAllSignupRequests());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
