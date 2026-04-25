import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/ritual_bloc.dart';
import '../view_model/rituals_analytics_large_screen_view_model.dart';

class RitualsAnalyticsLandingPage extends StatefulWidget {
  const RitualsAnalyticsLandingPage({super.key});

  @override
  State<RitualsAnalyticsLandingPage> createState() =>
      _RitualsAnalyticsLandingPageState();
}

class _RitualsAnalyticsLandingPageState extends State<RitualsAnalyticsLandingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RitualBloc>();
    if (bloc.state is RitualInitial) {
      bloc.add(LoadRitualAnalytics());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return const RitualsAnalyticsLargeScreenViewModel();
      },
    );
  }
}
