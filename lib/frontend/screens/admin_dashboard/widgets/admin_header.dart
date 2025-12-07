import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/models/admin_model.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/logout_helper.dart'; // NEW IMPORT

class AdminHeader extends StatelessWidget {
  final Admin admin;
  final String pageTitle;

  const AdminHeader({
    super.key,
    required this.admin,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: CustomColors.perla,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Page title
          Text(
            pageTitle,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CustomColors.verdeAbisso,
            ),
          ),

          const Spacer(),

          // Current time (you can keep this if you want)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    return Text(
                      _getCurrentTime(),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
              ),
              Text(
                _getCurrentDate(),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Admin profile with SIMPLIFIED popup menu
          Row(
            children: [
              CircleAvatar(
                backgroundColor: CustomColors.verdeMare,
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                admin.name,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.keyboard_arrow_down),
                offset: const Offset(0, 40),
                onSelected: (value) {
                  if (value == 'logout') {
                    // SIMPLIFIED LOGOUT - Just one line!
                    LogoutHelper.showLogoutConfirmation(context);
                  }
                  // Handle other menu items as needed
                },
                itemBuilder: (context) => [
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}