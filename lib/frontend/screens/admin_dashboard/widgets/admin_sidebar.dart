import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/context_extensions.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  void _showLogoutConfirmation(BuildContext context) {
    // Create a properly scoped context for the dialog
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

              context.read<AdminAuthBloc>().add(AdminLogoutRequested());
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: CustomColors.verdeAbisso, // Updated to match main app color scheme
      child: Column(
        children: [
          // Logo and admin title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: CustomColors.verdeAbisso, // Lighter accent color from app palette
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/logo/longeviva_logo_only_text.svg',
                  height: 40,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ],
            ),
          ),

          // Admin name (from authenticated admin)
          BlocBuilder<AdminAuthBloc, AdminAuthState>(
            builder: (context, state) {
              if (state is AdminAuthAuthenticated) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: CustomColors.verdeAbisso.withOpacity(0.8), // Slightly lighter than sidebar
                  child: Row(
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  title: 'Dashboard',
                  icon: Icons.dashboard,
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  title: 'Signup Requests',
                  icon: Icons.app_registration,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  title: 'User Management',
                  icon: Icons.people,
                ),
              ],
            ),
          ),

          // Logout button
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutConfirmation(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.rossoSimone,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
      }) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? CustomColors.verdeMare : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : CustomColors.perla.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: isSelected ? Colors.white : CustomColors.perla.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => onItemTapped(index),
        selected: isSelected,
      ),
    );
  }
}