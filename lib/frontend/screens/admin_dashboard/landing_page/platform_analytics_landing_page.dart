import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/platform_analytics_bloc.dart';
import '../view_model/platform_analytics_large_screen_view_model.dart';

class PlatformAnalyticsLandingPage extends StatefulWidget {
  const PlatformAnalyticsLandingPage({super.key});

  @override
  State<PlatformAnalyticsLandingPage> createState() =>
      _PlatformAnalyticsLandingPageState();
}

class _PlatformAnalyticsLandingPageState
    extends State<PlatformAnalyticsLandingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<PlatformAnalyticsBloc>();
    if (bloc.state is PlatformAnalyticsInitial) {
      bloc.add(LoadPlatformAnalytics());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const PlatformAnalyticsLargeScreenViewModel();
  }
}
