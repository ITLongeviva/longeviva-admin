import 'package:flutter/material.dart';
import '../../../../backend/models/admin_model.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/logout_helper.dart'; // NEW IMPORT

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
        if (value == 'logout') {
          // SIMPLIFIED LOGOUT
          LogoutHelper.showLogoutConfirmation(context);
        }
        // Handle other menu items...
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
            title: Text('My Profile', style: TextStyle(fontFamily: 'Montserrat')),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings, color: CustomColors.verdeAbisso),
            title: Text('Settings', style: TextStyle(fontFamily: 'Montserrat')),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: CustomColors.rossoSimone),
            title: Text('Logout', style: TextStyle(fontFamily: 'Montserrat', color: CustomColors.rossoSimone)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}