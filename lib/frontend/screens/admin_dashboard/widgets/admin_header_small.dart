import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/models/admin_model.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/context_extensions.dart';

class AdminHeaderSmall extends StatelessWidget {
  final Admin admin;

  const AdminHeaderSmall({
    super.key,
    required this.admin,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      icon: const CircleAvatar(
        backgroundColor: CustomColors.verdeMare,
        radius: 16,
        child: Icon(
          Icons.admin_panel_settings,
          color: Colors.white,
          size: 16,
        ),
      ),
      onSelected: (value) {
        if (value == 'profile') {
          // Handle profile
          context.showWarningAlert('Profile feature coming soon');
        } else if (value == 'settings') {
          // Handle settings
          context.showWarningAlert('Settings feature coming soon');
        } else if (value == 'logout') {
          // Show confirmation dialog before logout
          _showLogoutConfirmation(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile_info',
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin.name,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),
              Text(
                admin.email,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person, color: CustomColors.verdeAbisso),
            title: Text(
              'My Profile',
              style: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings, color: CustomColors.verdeAbisso),
            title: Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: CustomColors.rossoSimone),
            title: Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: CustomColors.rossoSimone,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    context.showAnimatedDialog(
      dialogBuilder: (dialogContext) => AlertDialog(
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

              // Use the original context which has access to the bloc
              final adminAuthBloc = BlocProvider.of<AdminAuthBloc>(context);
              adminAuthBloc.add(AdminLogoutRequested());
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