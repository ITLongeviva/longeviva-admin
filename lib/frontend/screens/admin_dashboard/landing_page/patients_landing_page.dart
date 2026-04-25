import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/patients_bloc.dart';
import '../view_model/patients_large_screen_view_model.dart';

class PatientsLandingPage extends StatelessWidget {
  const PatientsLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<PatientsBloc>().add(LoadPatients());

    return LayoutBuilder(
      builder: (context, constraints) {
        return const PatientsLargeScreenViewModel();
      },
    );
  }
}
