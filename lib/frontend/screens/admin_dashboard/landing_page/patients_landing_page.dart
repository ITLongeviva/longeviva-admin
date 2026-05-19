import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/patients_bloc.dart';
import '../view_model/patients_large_screen_view_model.dart';

class PatientsLandingPage extends StatefulWidget {
  const PatientsLandingPage({super.key});

  @override
  State<PatientsLandingPage> createState() => _PatientsLandingPageState();
}

class _PatientsLandingPageState extends State<PatientsLandingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<PatientsBloc>();
    if (bloc.state is PatientsInitial) {
      bloc.add(LoadPatients());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const PatientsLargeScreenViewModel();
  }
}
