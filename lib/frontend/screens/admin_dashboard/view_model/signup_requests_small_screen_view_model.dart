import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../backend/models/signup_request_model.dart';
import '../../../../../shared/utils/colors.dart';
import '../../../../../shared/utils/context_extensions.dart';
import '../../../../../shared/widgets/custom_progress_indicator.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../shared/utils/secure_password_generator.dart';
import '../../../../shared/widgets/password_validation_widget.dart';
import '../widgets/signup_request_details.dart';

class SignupRequestsSmallScreenViewModel extends StatefulWidget {
  const SignupRequestsSmallScreenViewModel({super.key});

  @override
  State<SignupRequestsSmallScreenViewModel> createState() =>
      _SignupRequestsSmallScreenViewModelState();
}

class _SignupRequestsSmallScreenViewModelState
    extends State<SignupRequestsSmallScreenViewModel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _roleFilter = 'all'; // NEW: Role filter

  @override
  void dispose() {
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
          // UPDATED: Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, role, or registration...', // UPDATED HINT
              prefixIcon:
              const Icon(Icons.search, color: CustomColors.verdeAbisso),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CustomColors.verdeAbisso),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: CustomColors.verdeAbisso, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(fontFamily: 'Montserrat'),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),

          const SizedBox(height: 16),

          // UPDATED: Filter and refresh controls
          Row(
            children: [
              Expanded(
                child: _buildStatusFilterDropdown(),
              ),
              const SizedBox(width: 8), // Adjusted spacing for small screen
              Expanded(
                child: _buildRoleFilterDropdown(), // NEW: Role filter dropdown
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context
                  .read<SignupRequestBloc>()
                  .add(FetchAllSignupRequests());
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.verdeAbisso,
              minimumSize: const Size(double.infinity, 48), // Make button full width
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Signup requests list
          Expanded(
            child: BlocConsumer<SignupRequestBloc, SignupRequestState>(
              listener: (context, state) {
                if (state is SignupRequestApproved) {
                  context.showSuccessAlert(
                      'Signup request approved successfully');
                } else if (state is SignupRequestRejected) {
                  context.showSuccessAlert(
                      'Signup request rejected successfully');
                } else if (state is SignupRequestError) {
                  context.showErrorAlert(state.message);
                }
              },
              builder: (context, state) {
                if (state is SignupRequestLoading) {
                  return const Center(
                    child: CustomProgressIndicator(
                      message: "Loading signup requests...",
                      color: CustomColors.verdeAbisso,
                    ),
                  );
                } else if (state is SignupRequestsLoaded) {
                  // UPDATED: Enhanced filtering logic with support for new model fields
                  final filteredRequests = state.requests.where((request) {
                    // Apply search filter
                    final name = ('${request.name} ${request.surname}').toLowerCase();
                    final email = request.email.toLowerCase();
                    final roles = request.roleDisplayNames.join(' ').toLowerCase(); // NEW: Multiple roles
                    final professionalReg = (request.professionalRegistrationNumber ?? '').toLowerCase(); // NEW
                    final specialty = (request.specialty ?? '').toLowerCase();
                    final city = request.cityOfWork.toLowerCase();

                    final matchesSearch = name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        roles.contains(_searchQuery) ||
                        professionalReg.contains(_searchQuery) ||
                        specialty.contains(_searchQuery) ||
                        city.contains(_searchQuery);

                    // Apply status filter
                    final matchesStatus =
                        _statusFilter == 'all' || request.status == _statusFilter;

                    // NEW: Apply role filter with enhanced matching
                    final matchesRole = _roleFilter == 'all' ||
                        request.hasRole(_roleFilter) ||
                        (_roleFilter == 'DOCTOR' && request.role == 'DOCTOR') || // Backward compatibility
                        (_roleFilter == 'CLINIC' && request.role == 'CLINIC');

                    return matchesSearch && matchesStatus && matchesRole;
                  }).toList();

                  if (filteredRequests.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = filteredRequests[index];
                      // Use the updated card method
                      return _buildRequestCardSmall(context, request);
                    },
                  );
                }

                return const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(fontFamily: 'Montserrat'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.app_registration,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No signup requests found',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // UPDATED: Condition for showing clear filters button
          if (_searchQuery.isNotEmpty ||
              _statusFilter != 'all' ||
              _roleFilter != 'all')
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = 'all';
                  _roleFilter = 'all'; // NEW: Reset role filter
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.verdeMare,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomColors.verdeAbisso.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _statusFilter = value;
              });
            }
          },
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.filter_list,
                      size: 20, color: CustomColors.verdeAbisso),
                  const SizedBox(width: 8),
                  Text(
                    'All Statuses',
                    style: TextStyle(
                        fontFamily: 'Montserrat', color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'pending',
              child: Row(
                children: [
                  Icon(Icons.pending, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Pending', style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'approved',
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Approved', style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'rejected',
              child: Row(
                children: [
                  Icon(Icons.cancel,
                      size: 20, color: CustomColors.rossoSimone),
                  SizedBox(width: 8),
                  Text('Rejected', style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Role filter dropdown
  Widget _buildRoleFilterDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomColors.verdeAbisso.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleFilter,
          isExpanded: true, // Important for small screen layout
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _roleFilter = value;
              });
            }
          },
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.group, size: 20, color: CustomColors.verdeAbisso),
                  const SizedBox(width: 8),
                  Text(
                    'All Roles',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'NUTRITIONIST',
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Prof. salute alimentare',
                      style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'PERSONAL TRAINER',
              child: Row(
                children: [
                  Icon(Icons.fitness_center, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Prof. salute motoria',
                      style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'PSYCHOLOGIST',
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 20, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Prof. salute mentale',
                      style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'DOCTOR',
              child: Row(
                children: [
                  Icon(Icons.medical_services,
                      size: 20, color: CustomColors.verdeMare),
                  SizedBox(width: 8),
                  Text('Doctor', style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'CLINIC',
              child: Row(
                children: [
                  Icon(Icons.local_hospital,
                      size: 20, color: CustomColors.verdeAbisso),
                  SizedBox(width: 8),
                  Text('Clinic', style: TextStyle(fontFamily: 'Montserrat')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Enhanced request card for small screen with full support for new model
  Widget _buildRequestCardSmall(BuildContext context, SignupRequest request) {
    final status = request.status;
    final primaryRole = request.roleDisplayNames.isNotEmpty ? request.roleDisplayNames.first : 'Unknown';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = CustomColors.rossoSimone;
        statusIcon = Icons.cancel;
        break;
      default: // pending
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: status == 'pending'
              ? CustomColors.verdeAbisso.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => SignupRequestDetails(request: request),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'On ${DateFormat('MMM d, yy').format(request.requestedAt)}', // Shorter date
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Name, icon, and roles
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, // Slightly larger icon container
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getRoleColor(primaryRole).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getRoleIcon(primaryRole),
                      color: _getRoleColor(primaryRole),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.name} ${request.surname}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 17, // Slightly larger name
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // UPDATED: Multiple roles display
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: request.roleDisplayNames.map((role) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Smaller padding
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 11, // Smaller font for roles
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                                color: _getRoleColor(role),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Specialty
              if (request.specialty.isNotEmpty)
                _buildInfoRow(
                    icon: Icons.medical_services_outlined,
                    text: request.specialty,
                    isItalic: true),

              // Email
              _buildInfoRow(icon: Icons.email, text: request.email),

              // Phone
              if (request.phoneNumber.isNotEmpty)
                _buildInfoRow(icon: Icons.phone, text: request.phoneNumber),

              // Location
              if (request.cityOfWork.isNotEmpty)
                _buildInfoRow(
                    icon: Icons.location_city,
                    text: '${request.cityOfWork}${request.countryOfWork != 'Italy' ? ', ${request.countryOfWork}' : ''}'
                ),

              // Professional Registration / VAT
              if (request.requiresProfessionalRegistration)
                _buildInfoRow(
                    icon: Icons.badge,
                    text: request.professionalRegistrationNumber ?? 'Registration pending')
              else if (request.vatNumber.isNotEmpty)
                _buildInfoRow(
                    icon: Icons.badge,
                    text: 'VAT: ${request.vatNumber}'),

              // NEW: Hourly fees display
              if (request.hasHourlyFeesSet)
                _buildInfoRow(
                    icon: Icons.euro,
                    text: '${request.formattedHourlyFees}/hour'),

              // Organization/Issuer
              if (request.issuer.isNotEmpty)
                _buildInfoRow(icon: Icons.business, text: request.issuer),

              // Professional Validation Status
              if (request.requiresProfessionalRegistration)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4), // Adjusted padding
                  child: Row(
                    children: [
                      Icon(
                        request.hasValidProfessionalRegistration
                            ? Icons.verified
                            : Icons.warning_amber_rounded, // Different icon for warning
                        size: 16,
                        color: request.hasValidProfessionalRegistration
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.hasValidProfessionalRegistration
                              ? 'Professional validation complete'
                              : 'Professional validation required',
                          style: TextStyle(
                            color: request.hasValidProfessionalRegistration
                                ? Colors.green
                                : Colors.orange,
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              if (status == 'pending') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRejectConfirmation(context, request.id);
                        },
                        icon: const Icon(Icons.cancel,
                            color: CustomColors.rossoSimone),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            color: CustomColors.rossoSimone,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side:
                          const BorderSide(color: CustomColors.rossoSimone),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        // UPDATED: Use proper validation check from new model
                        onPressed: request.hasValidProfessionalRegistration ? () {
                          _showApproveConfirmation(context, request.id);
                        } : null,
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          request.hasValidProfessionalRegistration ? 'Approve' : 'Validate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: request.hasValidProfessionalRegistration
                              ? CustomColors.verdeMare
                              : Colors.grey, // Grey out if disabled
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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

  // Helper for info rows to reduce repetition
  Widget _buildInfoRow({required IconData icon, required String text, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CustomColors.verdeAbisso.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Helper methods for role-specific styling
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'NUTRITIONIST':
      case 'NUTRIZIONISTA':
        return Colors.green;
      case 'PERSONAL TRAINER':
        return Colors.orange;
      case 'PSYCHOLOGIST':
      case 'PSICOLOGO':
        return Colors.purple;
      case 'DOCTOR':
      case 'DOTTORE':
        return CustomColors.verdeMare;
      case 'CLINIC':
      case 'CLINICA':
        return CustomColors.verdeAbisso;
      default:
        return CustomColors.verdeAbisso;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'NUTRITIONIST':
      case 'NUTRIZIONISTA':
        return Icons.restaurant_menu;
      case 'PERSONAL TRAINER':
        return Icons.fitness_center;
      case 'PSYCHOLOGIST':
      case 'PSICOLOGO':
        return Icons.psychology;
      case 'DOCTOR':
      case 'DOTTORE':
        return Icons.medical_services;
      case 'CLINIC':
      case 'CLINICA':
        return Icons.local_hospital;
      default:
        return Icons.person; // Default icon
    }
  }

  // --- DIALOGS (Identical to Large Screen version) ---
  void _showApproveConfirmation(BuildContext context, String requestId) {
    final temporaryPasswordController = TextEditingController();
    temporaryPasswordController.text =
        PasswordValidationHelper.generateValidatedPassword(length: 12);

    final signupRequestBloc = context.read<SignupRequestBloc>();

    context.showAnimatedDialog(
      dialogBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Confirm Approval',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to approve this signup request? This will create a new user account.',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
                const SizedBox(height: 16),
                PasswordValidationWidget(
                  passwordController: temporaryPasswordController,
                  onRegeneratePassword: () {
                    setState(() {
                      temporaryPasswordController.text =
                          PasswordValidationHelper.generateValidatedPassword(
                              length: 12);
                    });
                  },
                  showPasswordRequirements: false,
                  helperText: 'User will be required to change on first login',
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!PasswordValidationHelper.validateAndShowError(
                          context, temporaryPasswordController.text.trim())) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      signupRequestBloc.add(
                        ApproveSignupRequestWithPassword(
                          id: requestId,
                          temporaryPassword:
                          temporaryPasswordController.text,
                        ),
                      );
                    },
                    icon:
                    const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Approve',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.verdeMare,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectConfirmation(BuildContext context, String requestId) {
    final reasonController = TextEditingController();
    final signupRequestBloc = context.read<SignupRequestBloc>();

    context.showAnimatedDialog(
      dialogBuilder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirm Rejection',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: CustomColors.verdeAbisso,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to reject this signup request?',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  signupRequestBloc.add(
                    RejectSignupRequestWithReason(
                      id: requestId,
                      reason: reasonController.text,
                    ),
                  );
                },
                icon: const Icon(Icons.cancel,
                    color: CustomColors.rossoSimone),
                label: const Text(
                  'Reject',
                  style: TextStyle(
                    color: CustomColors.rossoSimone,
                    fontFamily: 'Montserrat',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: CustomColors.rossoSimone),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}