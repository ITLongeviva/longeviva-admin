import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/ritual_bloc.dart';
import '../view_model/rituals_analytics_large_screen_view_model.dart';

class RitualsAnalyticsLandingPage extends StatelessWidget {
  const RitualsAnalyticsLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<RitualBloc>().add(LoadRitualAnalytics());

    return LayoutBuilder(
      builder: (context, constraints) {
        return const RitualsAnalyticsLargeScreenViewModel();
      },
    );
  }
}
