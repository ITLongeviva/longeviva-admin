// lib/shared/utils/logout_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../backend/bloc/admin_auth_bloc.dart';
import 'colors.dart';
import 'context_extensions.dart';

class LogoutHelper {
  /// Show a confirmation dialog and handle logout
  static void showLogoutConfirmation(BuildContext context) {
    context.showAnimatedDialog(
      dialogBuilder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CustomColors.rossoSimone.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout,
                color: CustomColors.rossoSimone,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of the admin portal?',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Logout button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();

              // Trigger logout
              context.read<SimpleAdminAuthBloc>().add(LogoutRequested());
            },
            icon: const Icon(
              Icons.logout,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.rossoSimone,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Quick logout without confirmation (for debugging/development)
  static void quickLogout(BuildContext context) {
    context.read<SimpleAdminAuthBloc>().add(LogoutRequested());
  }

  /// Get logout button widget for use in app bars or menus
  static Widget getLogoutButton(BuildContext context, {bool showText = true}) {
    return BlocBuilder<SimpleAdminAuthBloc, SimpleAdminAuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        if (showText) {
          return ElevatedButton.icon(
            onPressed: isLoading ? null : () => showLogoutConfirmation(context),
            icon: isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.logout, size: 16),
            label: Text(
              isLoading ? 'Signing out...' : 'Sign Out',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.rossoSimone,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          return IconButton(
            onPressed: isLoading ? null : () => showLogoutConfirmation(context),
            icon: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(CustomColors.rossoSimone),
              ),
            )
                : const Icon(
              Icons.logout,
              color: CustomColors.rossoSimone,
            ),
            tooltip: 'Sign Out',
          );
        }
      },
    );
  }
}