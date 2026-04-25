import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/platform_analytics_bloc.dart';
import '../view_model/platform_analytics_large_screen_view_model.dart';

class PlatformAnalyticsLandingPage extends StatelessWidget {
  const PlatformAnalyticsLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<PlatformAnalyticsBloc>().add(LoadPlatformAnalytics());

    return LayoutBuilder(
      builder: (context, constraints) {
        return const PlatformAnalyticsLargeScreenViewModel();
      },
    );
  }
}
