import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../shared/utils/context_extensions.dart';
import '../view_model/signup_requests_large_screen_view_model.dart';
import '../view_model/signup_requests_small_screen_view_model.dart';

class SignupRequestsLandingPage extends StatelessWidget {
  const SignupRequestsLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger fetch when page loads
    context.read<SignupRequestBloc>().add(FetchAllSignupRequests());

    return BlocListener<SignupRequestBloc, SignupRequestState>(
      listener: (context, state) {
        if (state is SignupRequestApproved) {
          context.showSuccessAlert('Signup request approved successfully');
        } else if (state is SignupRequestRejected) {
          context.showSuccessAlert('Signup request rejected successfully');
        } else if (state is SignupRequestError) {
          context.showErrorAlert(state.message);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth <= 1000;

          if (isSmallScreen) {
            return const SignupRequestsSmallScreenViewModel();
          } else {
            return const SignupRequestsLargeScreenViewModel();
          }
        },
      ),
    );
  }
}