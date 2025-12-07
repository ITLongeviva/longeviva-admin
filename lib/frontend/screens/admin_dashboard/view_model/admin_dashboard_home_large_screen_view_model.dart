import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/utils/colors.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';

class AdminDashboardHomeLargeScreenViewModel extends StatelessWidget {
  const AdminDashboardHomeLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            const Text(
              'Welcome to the Admin Dashboard',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Here\'s an overview of your system',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // Dashboard cards in a row layout
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
                              .where((request) => request?.status == 'pending')
                              .length;
                        }

                        // Get user counts from AdminOperationsBloc
                        if (adminState is AllUsersLoaded) {
                          totalUsers = adminState.users.length;
                          doctorCount = adminState.users.where((user) => user['type'] == 'doctor').length;
                          patientCount = adminState.users.where((user) => user['type'] == 'patient').length;
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Users',
                                value: totalUsers.toString(),
                                icon: Icons.people,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Doctors',
                                value: doctorCount.toString(),
                                icon: Icons.medical_services,
                                color: CustomColors.verdeMare,
                              ),
                            ),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Patients',
                                value: patientCount.toString(),
                                icon: Icons.personal_injury,
                                color: CustomColors.verdeTropicale,
                              ),
                            ),
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
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // System information
            const Text(
              'System Information',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),

            const SizedBox(height: 16),

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
          padding: const EdgeInsets.all(20),
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
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 28,
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
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label + ':',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
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
    return Expanded(
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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