import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/doctors_bloc.dart';
import '../view_model/doctors_large_screen_view_model.dart';

class DoctorsLandingPage extends StatelessWidget {
  const DoctorsLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<DoctorsBloc>().add(LoadDoctors());

    return LayoutBuilder(
      builder: (context, constraints) {
        return const DoctorsLargeScreenViewModel();
      },
    );
  }
}
