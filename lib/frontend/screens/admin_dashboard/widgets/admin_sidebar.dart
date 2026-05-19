import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/logout_helper.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: CustomColors.verdeAbisso,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: SvgPicture.asset(
              'assets/icons/logo/longeviva_logo_only_text.svg',
              height: 40,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),

          // Admin info
          BlocBuilder<SimpleAdminAuthBloc, SimpleAdminAuthState>(
            builder: (context, state) {
              if (state is AuthSuccess) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: CustomColors.verdeAbisso.withOpacity(0.8),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: CustomColors.verdeMare,
                        child: Icon(Icons.admin_panel_settings, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.admin.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              state.admin.email,
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
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Navigation items
          Expanded(
            child: BlocBuilder<SignupRequestBloc, SignupRequestState>(
              builder: (context, signupState) {
                int pendingCount = 0;
                if (signupState is SignupRequestsLoaded) {
                  pendingCount = signupState.requests
                      .where((r) => r?.status == 'pending')
                      .length;
                }
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildNavItem(context, index: 0, title: 'Dashboard', icon: Icons.dashboard),
                    _buildNavItem(
                      context,
                      index: 1,
                      title: 'Signup Requests',
                      icon: Icons.app_registration,
                      badgeCount: pendingCount,
                    ),
                    _buildNavItem(context, index: 2, title: 'User Management', icon: Icons.people),
                    _buildNavItem(context, index: 3, title: 'Rituali', icon: Icons.auto_awesome),
                    _buildNavItem(context, index: 4, title: 'Analytics Piattaforma', icon: Icons.bar_chart),
                    _buildNavItem(context, index: 5, title: 'Dottori', icon: Icons.medical_services),
                    _buildNavItem(context, index: 6, title: 'Pazienti', icon: Icons.personal_injury),
                  ],
                );
              },
            ),
          ),

          // Logout
          Container(
            padding: const EdgeInsets.all(16),
            child: LogoutHelper.getLogoutButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String title,
    required IconData icon,
    int badgeCount = 0,
  }) {
    final isSelected = selectedIndex == index;
    final iconColor = isSelected ? Colors.white : CustomColors.perla.withOpacity(0.7);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? CustomColors.verdeMare : Colors.transparent,
      ),
      child: ListTile(
        leading: badgeCount > 0
            ? Badge(
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: CustomColors.rossoSimone,
                child: Icon(icon, color: iconColor),
              )
            : Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: isSelected ? Colors.white : CustomColors.perla.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => onItemTapped(index),
      ),
    );
  }
}
