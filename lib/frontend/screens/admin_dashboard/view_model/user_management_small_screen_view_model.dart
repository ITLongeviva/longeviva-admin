import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../backend/models/doctor/doctor_model.dart';
import '../../../../../shared/utils/colors.dart';
import '../../../../../shared/utils/context_extensions.dart';
import '../../../../../shared/widgets/custom_progress_indicator.dart';
import '../../../../backend/bloc/admin_bloc.dart';

class UserManagementSmallScreenViewModel extends StatefulWidget {
  const UserManagementSmallScreenViewModel({super.key});

  @override
  State<UserManagementSmallScreenViewModel> createState() => _UserManagementSmallScreenViewModelState();
}

class _UserManagementSmallScreenViewModelState extends State<UserManagementSmallScreenViewModel> with SingleTickerProviderStateMixin {
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

  // NEW: Helper method to get role color
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'NUTRITIONIST':
      case 'NUTRIZIONISTA':
        return Colors.green;
      case 'PERSONAL TRAINER':
        return Colors.orange;
      case 'PSYCHOLOGIST':
      case 'PSICOLOGO':
        return Colors.blue;
      default:
        return CustomColors.verdeAbisso;
    }
  }

  // NEW: Helper method to get role icon
  IconData _getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'NUTRITIONIST':
      case 'NUTRIZIONISTA':
        return Icons.restaurant;
      case 'PERSONAL TRAINER':
        return Icons.fitness_center;
      case 'PSYCHOLOGIST':
      case 'PSICOLOGO':
        return Icons.psychology;
      default:
        return Icons.medical_services;
    }
  }

  // NEW: Helper method to format roles list for display
  List<String> _getRoleDisplayNames(dynamic rolesData) {
    if (rolesData == null) return ['N/A'];

    List<String> roles = [];
    if (rolesData is List) {
      roles = List<String>.from(rolesData);
    } else if (rolesData is String) {
      roles = [rolesData];
    }

    const roleMap = {
      'NUTRITIONIST': 'Professionista salute alimentare',
      'PERSONAL TRAINER': 'Professionista salute motoria',
      'PSYCHOLOGIST': 'Professionista salute mentale',
    };

    return roles.map((role) => roleMap[role.toUpperCase()] ?? role).toList();
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
                  : null,
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

          const SizedBox(height: 16),

          // Refresh button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<AdminOperationsBloc>().add(FetchAllUsers());
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Refresh User List',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.verdeAbisso,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

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
                Tab(text: 'All Users'),
                Tab(text: 'Doctors'),
                Tab(text: 'Patients'),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
        return _buildUserCardSmall(context, user);
      },
    );
  }

  Widget _buildUserCardSmall(BuildContext context, Map<String, dynamic> user) {
    final userType = user['type'];
    // UPDATED: Handle both old single role and new multiple roles
    final userRoles = _getRoleDisplayNames(user['roles'] ?? user['role']);
    final primaryRole = userRoles.isNotEmpty ? userRoles.first : '';

    // UPDATED: Choose color based on primary role
    Color cardColor = CustomColors.verdeAbisso;
    IconData typeIcon = Icons.medical_services;

    if (userType == 'doctor' && userRoles.isNotEmpty) {
      cardColor = _getRoleColor(userRoles.first);
      typeIcon = _getRoleIcon(userRoles.first);
    } else if (userType == 'patient') {
      cardColor = CustomColors.mentaFredda;
      typeIcon = Icons.personal_injury;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showUserDetailsDialog(context, user);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user type and roles
              Row(
                children: [
                  // User icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      typeIcon,
                      color: cardColor,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // User name and roles
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['name']} ${user['surname'] ?? ''}'.trim(),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        Row(
                          children: [
                            Text(
                              capitalize(userType),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),

                            // UPDATED: Show roles as chips for doctors
                            if (userType == 'doctor' && userRoles.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: userRoles.take(2).map((role) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(role).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getRoleColor(role),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Delete button
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: CustomColors.rossoSimone,
                      size: 20,
                    ),
                    onPressed: () {
                      _showDeleteConfirmation(context, user['id'], userType);
                    },
                  ),
                ],
              ),

              const Divider(height: 16),

              // Email
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: CustomColors.verdeAbisso,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user['email'] ?? 'No email available',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Specialty for doctors
              if (userType == 'doctor' && user['specialty'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 16,
                      color: CustomColors.verdeAbisso,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user['specialty'],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // City for doctors
              if (userType == 'doctor' && user['cityOfWork'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_city_outlined,
                      size: 16,
                      color: CustomColors.verdeAbisso,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user['cityOfWork'],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // NEW: Hourly fees for doctors
              if (userType == 'doctor' && user['hourlyFees'] != null && user['hourlyFees'] > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.euro_outlined,
                      size: 16,
                      color: CustomColors.verdeAbisso,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '€${user['hourlyFees'].toStringAsFixed(0)}/h',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context, Map<String, dynamic> user) {
    final userType = user['type'];
    // UPDATED: Handle multiple roles
    final userRoles = _getRoleDisplayNames(user['roles'] ?? user['role']);
    final primaryRole = userRoles.isNotEmpty ? userRoles.first : '';

    context.showAnimatedDialog(
      dialogBuilder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              Row(
                children: [
                  Icon(
                    userType == 'doctor'
                        ? _getRoleIcon(primaryRole)
                        : Icons.personal_injury,
                    size: 24,
                    color: userType == 'doctor'
                        ? _getRoleColor(primaryRole)
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const Divider(height: 24),

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
                        // UPDATED: Show all roles instead of single role
                        _buildDetailItem('Role(s)', userRoles.join(', ')),
                        _buildDetailItem('Specialty', user['specialty'] ?? 'N/A'),
                        if (user['cityOfWork'] != null)
                          _buildDetailItem('City of Work', user['cityOfWork']),
                        // NEW: Show country of work
                        if (user['countryOfWork'] != null)
                          _buildDetailItem('Country of Work', user['countryOfWork']),
                        // NEW: Show professional registration numbers
                        if (user['numero_iscrizione_albo'] != null)
                          _buildDetailItem('Registration (Albo)', user['numero_iscrizione_albo']),
                        if (user['numero_iscrizione_ente'] != null)
                          _buildDetailItem('Registration (Ente)', user['numero_iscrizione_ente']),
                        // Certification data (current format)
                        if (user['registrationEntityType'] != null &&
                            user['registrationEntityType'].toString().isNotEmpty)
                          _buildDetailItem('Certification Type',
                              _registrationEntityTypeLabel(user['registrationEntityType'])),
                        if (user['registrationValue'] != null &&
                            user['registrationValue'].toString().isNotEmpty)
                          _buildDetailItem('Issuing Institution', user['registrationValue']),
                        // LEGACY: Show issuer
                        if (user['issuer'] != null && user['issuer'].toString().isNotEmpty)
                          _buildDetailItem('Qualification Issuer', user['issuer']),
                        // NEW: Show hourly fees
                        if (user['hourlyFees'] != null)
                          _buildDetailItem('Hourly Fees', user['hourlyFees'] > 0
                              ? '€${user['hourlyFees'].toStringAsFixed(2)}'
                              : 'Not specified'),
                        // NEW: Show languages spoken
                        if (user['languagesSpoken'] != null && user['languagesSpoken'] is List)
                          _buildDetailItem('Languages', (user['languagesSpoken'] as List).join(', ')),
                        // NEW: Show area of interest
                        if (user['areaOfInterest'] != null && user['areaOfInterest'].toString().isNotEmpty)
                          _buildDetailItem('Area of Interest', user['areaOfInterest']),
                        // NEW: Show VAT number
                        if (user['vatNumber'] != null && user['vatNumber'].toString().isNotEmpty)
                          _buildDetailItem('VAT Number', user['vatNumber']),
                        // NEW: Show fiscal code
                        if (user['fiscalCode'] != null && user['fiscalCode'].toString().isNotEmpty)
                          _buildDetailItem('Fiscal Code', user['fiscalCode']),
                      ],

                      const SizedBox(height: 16),

                      // Delete button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showDeleteConfirmation(context, user['id'], userType);
                          },
                          icon: const Icon(Icons.delete, color: CustomColors.rossoSimone),
                          label: const Text(
                            'Delete User',
                            style: TextStyle(
                              color: CustomColors.rossoSimone,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: CustomColors.rossoSimone),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
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

  // Human-readable label for the certification type stored in Firestore
  static String _registrationEntityTypeLabel(dynamic value) {
    switch (value.toString().trim().toLowerCase()) {
      case 'universita':
      case 'università':
        return 'Laurea';
      case 'ente':
        return 'Tesserino';
      case 'attestato':
        return 'Attestato';
      default:
        return value.toString();
    }
  }

}