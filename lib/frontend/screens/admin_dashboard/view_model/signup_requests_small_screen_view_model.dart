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
  State<SignupRequestsSmallScreenViewModel> createState() => _SignupRequestsSmallScreenViewModelState();
}

class _SignupRequestsSmallScreenViewModelState extends State<SignupRequestsSmallScreenViewModel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

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
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search, color: CustomColors.verdeAbisso),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CustomColors.verdeAbisso),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CustomColors.verdeAbisso, width: 2),
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

          // Filter and refresh controls
          Row(
            children: [
              Expanded(
                child: _buildStatusFilterDropdown(),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Refresh using SignupRequestBloc
                  context.read<SignupRequestBloc>().add(FetchAllSignupRequests());
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.verdeAbisso,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Signup requests list
          Expanded(
            child: BlocConsumer<SignupRequestBloc, SignupRequestState>(
              listener: (context, state) {
                if (state is SignupRequestApproved) {
                  context.showSuccessAlert('Signup request approved successfully');
                } else if (state is SignupRequestRejected) {
                  context.showSuccessAlert('Signup request rejected successfully');
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
                  // Filter requests based on search query and status filter
                  final filteredRequests = state.requests.where((request) {
                    // Apply search filter
                    final name = ('${request.name} ${request.surname}').toLowerCase();
                    final email = request.email.toLowerCase();
                    final matchesSearch = name.contains(_searchQuery) || email.contains(_searchQuery);

                    // Apply status filter
                    final matchesStatus = _statusFilter == 'all' || request.status == _statusFilter;

                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filteredRequests.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = filteredRequests[index];
                      return _buildRequestCardSmall(context, request);
                    },
                  );
                }

                // Default state or error state
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
          if (_searchQuery.isNotEmpty || _statusFilter != 'all')
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = 'all';
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
                  Icon(Icons.filter_list, size: 20, color: CustomColors.verdeAbisso),
                  const SizedBox(width: 8),
                  const Text(
                    'All Statuses',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                    ),
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
                  Icon(Icons.cancel, size: 20, color: CustomColors.rossoSimone),
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

  Widget _buildRequestCardSmall(BuildContext context, SignupRequest request) {
    final status = request.status;
    final role = request.role;

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
          color: status == 'pending' ? CustomColors.verdeAbisso.withOpacity(0.3) : Colors.transparent,
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
              // Status and role badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: role == 'DOCTOR' ? CustomColors.verdeMare.withOpacity(0.1) : CustomColors.verdeAbisso.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        color: role == 'DOCTOR' ? CustomColors.verdeMare : CustomColors.verdeAbisso,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Name and date
              Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: role == 'DOCTOR' ? CustomColors.verdeMare.withOpacity(0.2) : CustomColors.verdeAbisso.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      role == 'DOCTOR' ? Icons.medical_services : Icons.local_hospital,
                      color: role == 'DOCTOR' ? CustomColors.verdeMare : CustomColors.verdeAbisso,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.name} ${request.surname}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Date
                        Text(
                          'Requested on ${DateFormat('MMM d, yyyy').format(request.requestedAt)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Specialty and email
              if (request.specialty.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 16, color: CustomColors.verdeAbisso),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.specialty,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Montserrat',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: CustomColors.verdeAbisso),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.email,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (request.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: CustomColors.verdeAbisso),
                    const SizedBox(width: 8),
                    Text(
                      request.phoneNumber,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],

              if (request.cityOfWork.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_city, size: 16, color: CustomColors.verdeAbisso),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.cityOfWork,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Action buttons - only show for pending requests
              if (status == 'pending') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRejectConfirmation(context, request.id);
                        },
                        icon: const Icon(Icons.cancel, color: CustomColors.rossoSimone),
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showApproveConfirmation(context, request.id);
                        },
                        icon: const Icon(Icons.check_circle, color: Colors.white),
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

  void _showApproveConfirmation(BuildContext context, String requestId) {
    final temporaryPasswordController = TextEditingController();
    // Use the unified password generator with validation
    temporaryPasswordController.text = PasswordValidationHelper.generateValidatedPassword(length: 12);

    // Capture the bloc before showing dialog
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

                // Use the unified password validation widget - IDENTICAL to large screen
                PasswordValidationWidget(
                  passwordController: temporaryPasswordController,
                  onRegeneratePassword: () {
                    setState(() {
                      temporaryPasswordController.text = PasswordValidationHelper.generateValidatedPassword(length: 12);
                    });
                  },
                  showPasswordRequirements: false, // Compact version for dialog
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
                      // Use unified validation helper - IDENTICAL validation logic!
                      if (!PasswordValidationHelper.validateAndShowError(context, temporaryPasswordController.text.trim())) {
                        return;
                      }

                      Navigator.of(dialogContext).pop();

                      // Use the captured bloc reference
                      signupRequestBloc.add(
                        ApproveSignupRequestWithPassword(
                          id: requestId,
                          temporaryPassword: temporaryPasswordController.text,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
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

    // Capture the bloc before showing dialog
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

                  // Use the captured bloc reference
                  signupRequestBloc.add(
                    RejectSignupRequestWithReason(
                      id: requestId,
                      reason: reasonController.text,
                    ),
                  );
                },
                icon: const Icon(Icons.cancel, color: CustomColors.rossoSimone),
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