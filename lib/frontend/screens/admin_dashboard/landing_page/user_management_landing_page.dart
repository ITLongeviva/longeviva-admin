import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../view_model/user_management_large_screen_view_model.dart';
import '../view_model/user_management_small_screen_view_model.dart';

class UsersManagementPageLandingPage extends StatefulWidget {
  const UsersManagementPageLandingPage({super.key});

  @override
  State<UsersManagementPageLandingPage> createState() =>
      _UsersManagementPageLandingPageState();
}

class _UsersManagementPageLandingPageState
    extends State<UsersManagementPageLandingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AdminOperationsBloc>();
    if (bloc.state is AdminOperationsInitial) {
      bloc.add(FetchAllUsers());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
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
