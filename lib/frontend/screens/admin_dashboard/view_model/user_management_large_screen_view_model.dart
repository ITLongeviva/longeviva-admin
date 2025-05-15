import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../backend/models/doctor/doctor_model.dart';
import '../../../../../shared/utils/colors.dart';
import '../../../../../shared/utils/context_extensions.dart';
import '../../../../../shared/widgets/custom_progress_indicator.dart';
import '../../../../backend/bloc/admin_bloc.dart';

class UserManagementLargeScreenViewModel extends StatefulWidget {
  const UserManagementLargeScreenViewModel({super.key});

  @override
  State<UserManagementLargeScreenViewModel> createState() => _UserManagementLargeScreenViewModelState();
}

class _UserManagementLargeScreenViewModelState extends State<UserManagementLargeScreenViewModel> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        // Clear search when tab changes
        _searchController.clear();
        _searchQuery = '';
      });
    }
  }

  String capitalize(String text) {
    return text.isNotEmpty ? '${text[0].toUpperCase()}${text.substring(1)}' : text;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar and action buttons in row layout
          Row(
            children: [
              // Search field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Refresh button
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AdminOperationsBloc>().add(FetchAllUsers());
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.verdeAbisso,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[700],
              indicator: BoxDecoration(
                color: CustomColors.verdeAbisso,
                borderRadius: BorderRadius.circular(8),
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people),
                      SizedBox(width: 8),
                      Text('All Users'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services),
                      SizedBox(width: 8),
                      Text('Doctors'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.personal_injury),
                      SizedBox(width: 8),
                      Text('Patients'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tab content
          Expanded(
            child: BlocConsumer<AdminOperationsBloc, AdminOperationsState>(
              listener: (context, state) {
                if (state is OperationSuccess) {
                  context.showSuccessAlert(state.message);
                } else if (state is OperationFailure) {
                  context.showErrorAlert(state.error);
                }
              },
              builder: (context, state) {
                if (state is AdminOperationsLoading) {
                  return const Center(
                    child: CustomProgressIndicator(
                      message: "Loading users...",
                    ),
                  );
                } else if (state is AllUsersLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // All users tab
                      _buildUsersList(
                        state.users.where((user) {
                          final name = '${user['name']} ${user['surname'] ?? ''}'.toLowerCase();
                          final email = (user['email'] ?? '').toLowerCase();
                          return name.contains(_searchQuery) || email.contains(_searchQuery);
                        }).toList(),
                      ),

                      // Doctors tab
                      _buildUsersList(
                        state.users.where((user) {
                          // Filter by type and search query
                          final name = '${user['name']} ${user['surname'] ?? ''}'.toLowerCase();
                          final email = (user['email'] ?? '').toLowerCase();
                          return user['type'] == 'doctor' && (name.contains(_searchQuery) || email.contains(_searchQuery));
                        }).toList(),
                      ),

                      // Patients tab
                      _buildUsersList(
                        state.users.where((user) {
                          // Filter by type and search query
                          final name = '${user['name']} ${user['surname'] ?? ''}'.toLowerCase();
                          final email = (user['email'] ?? '').toLowerCase();
                          return user['type'] == 'patient' && (name.contains(_searchQuery) || email.contains(_searchQuery));
                        }).toList(),
                      ),
                    ],
                  );
                }

                // Default state or error state
                return const Center(
                  child: Text('No data available'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(context, user);
      },
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final userType = user['type'];
    final userRole = user['role'] ?? '';

    // Choose color based on user type
    Color cardColor;
    IconData typeIcon;

    if (userType == 'doctor') {
      cardColor = userRole == Doctor.ROLE_CLINIC ? CustomColors.verdeAbisso : CustomColors.verdeMare;
      typeIcon = userRole == Doctor.ROLE_CLINIC ? Icons.local_hospital : Icons.medical_services;
    } else {
      cardColor = CustomColors.mentaFredda;
      typeIcon = Icons.personal_injury;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // User icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                typeIcon,
                color: cardColor,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // User details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user['name']} ${user['surname'] ?? ''}'.trim(),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (userType == 'doctor' && userRole.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: userRole == Doctor.ROLE_CLINIC
                                ? CustomColors.verdeAbisso.withOpacity(0.1)
                                : CustomColors.verdeMare.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            userRole,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: userRole == Doctor.ROLE_CLINIC
                                  ? CustomColors.verdeAbisso
                                  : CustomColors.verdeMare,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // User email
                  Text(
                    user['email'] ?? 'No email available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),

                  // Additional info for doctors
                  if (userType == 'doctor' && user['specialty'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user['specialty'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Action buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: CustomColors.verdeAbisso),
                  tooltip: 'View Details',
                  onPressed: () {
                    _showUserDetailsDialog(context, user);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: CustomColors.rossoSimone),
                  tooltip: 'Delete User',
                  onPressed: () {
                    _showDeleteConfirmation(context, user['id'], userType);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context, Map<String, dynamic> user) {
    final userType = user['type'];
    final userRole = user['role'] ?? '';

    context.showAnimatedDialog(
      dialogBuilder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              Row(
                children: [
                  Icon(
                    userType == 'doctor'
                        ? (userRole == Doctor.ROLE_CLINIC ? Icons.local_hospital : Icons.medical_services)
                        : Icons.personal_injury,
                    size: 24,
                    color: userType == 'doctor'
                        ? (userRole == Doctor.ROLE_CLINIC ? CustomColors.verdeAbisso : CustomColors.verdeMare)
                        : CustomColors.mentaFredda,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'User Details',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const Divider(),

              // User details content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem('Name', '${user['name']} ${user['surname'] ?? ''}'),
                      _buildDetailItem('Email', user['email'] ?? 'N/A'),
                      _buildDetailItem('User Type', capitalize(userType)),

                      if (userType == 'doctor') ...[
                        _buildDetailItem('Role', userRole),
                        _buildDetailItem('Specialty', user['specialty'] ?? 'N/A'),
                        if (user['placeOfWork'] != null)
                          _buildDetailItem('Place of Work', user['placeOfWork']),
                        if (user['cityOfWork'] != null)
                          _buildDetailItem('City of Work', user['cityOfWork']),
                      ],

                      const SizedBox(height: 24),

                      // Actions section
                      const Text(
                        'Actions',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showDeleteConfirmation(context, user['id'], userType);
                            },
                            icon: const Icon(Icons.delete, color: CustomColors.rossoSimone),
                            label: const Text(
                              'Delete User',
                              style: TextStyle(color: CustomColors.rossoSimone),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: CustomColors.rossoSimone),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label + ':',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String userId, String userType) {
    context.showAnimatedDialog(
      dialogBuilder: (context) => AlertDialog(
        title: const Text('Confirm User Deletion'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Colors.black87,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to delete this '),
              TextSpan(
                text: userType,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.rossoSimone,
            ),
            onPressed: () {
              Navigator.of(context).pop();

              // Dispatch delete event
              context.read<AdminOperationsBloc>().add(
                DeleteUser(userId: userId, userType: userType),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}