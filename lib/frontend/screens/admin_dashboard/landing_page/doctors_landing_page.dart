import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/doctors_bloc.dart';
import '../view_model/doctors_large_screen_view_model.dart';

class DoctorsLandingPage extends StatefulWidget {
  const DoctorsLandingPage({super.key});

  @override
  State<DoctorsLandingPage> createState() => _DoctorsLandingPageState();
}

class _DoctorsLandingPageState extends State<DoctorsLandingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<DoctorsBloc>();
    if (bloc.state is DoctorsInitial) {
      bloc.add(LoadDoctors());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const DoctorsLargeScreenViewModel();
  }
}
