import 'package:flutter/material.dart';
import '../../../../backend/models/admin_model.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_header.dart';
import '../landing_page/admin_dashboard_home_landing_page.dart';
import '../landing_page/signup_requests_landing_page.dart';
import '../landing_page/user_management_landing_page.dart';

class AdminDashboardLargeScreenViewModel extends StatelessWidget {
  final Admin admin;
  final int selectedIndex;
  final Function(int) onItemTapped;
  final PageController pageController;
  final String pageTitle;

  const AdminDashboardLargeScreenViewModel({
    super.key,
    required this.admin,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.pageController,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Admin sidebar - always visible on large screens
          AdminSidebar(
            selectedIndex: selectedIndex,
            onItemTapped: onItemTapped,
          ),

          // Main content area
          Flexible(
            child: Column(
              children: [
                // Header
                AdminHeader(
                  admin: admin,
                  pageTitle: pageTitle,
                ),

                // Page content
                Flexible(
                  child: PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => onItemTapped(index),
                    children: const [
                      AdminDashboardHome(),
                      SignupRequestsLandingPage(),
                      UsersManagementPageLandingPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}