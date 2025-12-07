import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/utils/colors.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';

class AdminDashboardHomeSmallScreenViewModel extends StatelessWidget {
  const AdminDashboardHomeSmallScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            const Text(
              'Welcome to the Admin Dashboard',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Here\'s an overview of your system',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 24),

            // Dashboard cards in a grid layout for small screens
            MultiBlocBuilder<Object>(
              builders: [
                BlocBuilder<AdminOperationsBloc, AdminOperationsState>(
                  builder: (context, adminState) {
                    return BlocBuilder<SignupRequestBloc, SignupRequestState>(
                      builder: (context, signupState) {
                        // Extract data from various states to show summary
                        int pendingSignupRequests = 0;
                        int totalUsers = 0;
                        int doctorCount = 0;
                        int patientCount = 0;

                        // Get pending signup requests count from SignupRequestBloc
                        if (signupState is SignupRequestsLoaded) {
                          pendingSignupRequests = signupState.requests
                              .where((request) => request.status == 'pending')
                              .length;
                        }

                        // Get user counts from AdminOperationsBloc
                        if (adminState is AllUsersLoaded) {
                          totalUsers = adminState.users.length;
                          doctorCount = adminState.users.where((user) => user['type'] == 'doctor').length;
                          patientCount = adminState.users.where((user) => user['type'] == 'patient').length;
                        }

                        return Column(
                          children: [
                            // First row of cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Total Users',
                                    value: totalUsers.toString(),
                                    icon: Icons.people,
                                    color: CustomColors.verdeAbisso,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Doctors',
                                    value: doctorCount.toString(),
                                    icon: Icons.medical_services,
                                    color: CustomColors.verdeMare,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Second row of cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Patients',
                                    value: patientCount.toString(),
                                    icon: Icons.personal_injury,
                                    color: CustomColors.verdeTropicale,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Pending Requests',
                                    value: pendingSignupRequests.toString(),
                                    icon: Icons.app_registration,
                                    color: CustomColors.rossoSimone,
                                    onTap: () {
                                      // Navigate to signup requests page
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // System information
            const Text(
              'System Information',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),

            const SizedBox(height: 12),

            // System info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Firebase Status', 'Connected', Icons.cloud_done, Colors.green),
                    const Divider(),
                    _buildInfoRow('App Version', '1.0.0', Icons.info_outline, CustomColors.verdeAbisso),
                    const Divider(),
                    _buildInfoRow('Last Backup', 'Today at 03:00 AM', Icons.backup, CustomColors.verdeMare),
                    const Divider(),
                    _buildInfoRow('System Load', 'Normal', Icons.speed, CustomColors.verdeTropicale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label + ':',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
          ),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// A utility widget to handle multiple BlocBuilders
class MultiBlocBuilder<T> extends StatelessWidget {
  final List<Widget> builders;

  const MultiBlocBuilder({
    super.key,
    required this.builders,
  });

  @override
  Widget build(BuildContext context) {
    if (builders.isEmpty) {
      return const SizedBox.shrink();
    }

    return builders.first;
  }
}