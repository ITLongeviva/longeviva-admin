import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../../shared/utils/colors.dart';
import '../../../../backend/models/admin_model.dart';
import '../landing_page/admin_dashboard_home_landing_page.dart';
import '../landing_page/signup_requests_landing_page.dart';
import '../widgets/admin_header_small.dart';
import '../landing_page/user_management_landing_page.dart';

class AdminDashboardSmallScreenViewModel extends StatelessWidget {
  final Admin admin;
  final int selectedIndex;
  final Function(int) onItemTapped;
  final PageController pageController;
  final String pageTitle;

  const AdminDashboardSmallScreenViewModel({
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
      appBar: AppBar(
        backgroundColor: CustomColors.verdeAbisso,
        title: SvgPicture.asset(
          "assets/icons/logo/longeviva_logo_only_text.svg",
          height: 40,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        actions: [
          // Small header with admin info
          AdminHeaderSmall(admin: admin),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: CustomColors.verdeAbisso,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: CustomColors.verdeAbisso,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      "assets/icons/logo/longeviva_logo_only_text.svg",
                      height: 40,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: CustomColors.verdeMare,
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                admin.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                admin.email,
                                style: const TextStyle(
                                  color: CustomColors.perla,
                                  fontSize: 12,
                                  fontFamily: 'Montserrat',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                title: 'Dashboard',
                icon: Icons.dashboard,
                index: 0,
                context: context
              ),
              _buildDrawerItem(
                title: 'Signup Requests',
                icon: Icons.app_registration,
                index: 1,
                context: context
              ),
              _buildDrawerItem(
                title: 'User Management',
                icon: Icons.people,
                index: 2,
                  context: context
              ),
              const Divider(color: Colors.white30),
              _buildDrawerItem(
                title: 'Logout',
                icon: Icons.logout,
                index: -1, // Special index for logout
                isLogout: true,
                  context: context
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Page title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: CustomColors.perla,
            width: double.infinity,
            child: Text(
              pageTitle,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),
          ),

          // Page content
          Expanded(
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
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required int index,
    required BuildContext context,
    bool isLogout = false,
  }) {
    final isSelected = index == selectedIndex;
    final color = isLogout ? CustomColors.rossoSimone : CustomColors.biancoPuro;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? CustomColors.verdeMare : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : color.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: isSelected ? Colors.white : color.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          if (isLogout) {
            // Show logout confirmation dialog
            _showLogoutConfirmation(context);
          } else {
            onItemTapped(index);
            Navigator.pop(context); // Close drawer
          }
        },
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    // Navigate back first to close the drawer
    Navigator.pop(context);

    // Then show the dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: CustomColors.verdeAbisso,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            fontFamily: 'Montserrat',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.rossoSimone,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();

              // Navigate to login page
              Navigator.of(context).pushNamedAndRemoveUntil('/admin_login', (route) => false);
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}