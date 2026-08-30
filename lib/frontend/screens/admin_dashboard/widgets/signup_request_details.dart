import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../backend/models/signup_request_model.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/context_extensions.dart';
import '../../../../shared/widgets/password_validation_widget.dart';

class SignupRequestDetails extends StatefulWidget {
  final SignupRequest request;

  const SignupRequestDetails({super.key, required this.request});

  @override
  State<SignupRequestDetails> createState() => _SignupRequestDetailsState();
}

class _SignupRequestDetailsState extends State<SignupRequestDetails> {
  final TextEditingController _tempPasswordController = TextEditingController();

  @override
  void dispose() {
    _tempPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tempPasswordController.text =
        PasswordValidationHelper.generateValidatedPassword(length: 12);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 700,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // UPDATED: Use primary role display name with multiple roles support
                        '${_getPrimaryRoleDisplayName()} Registration Request',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.verdeAbisso,
                        ),
                      ),
                      // UPDATED: Show all roles if multiple
                      if (widget.request.roles.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Roles: ${widget.request.roleDisplayNames.join(', ')}',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Request ID: ${widget.request.id}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(),

            // Request details with scrolling
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and date
                    _buildStatusSection(widget.request),

                    const SizedBox(height: 16),

                    // Personal details
                    _buildSection(
                      title: 'Personal Information',
                      icon: Icons.person,
                      children: [
                        _buildDetailRow('Full Name', _getFullName()),
                        // UPDATED: Show sex and birthdate for professional roles
                        if (widget.request.sex.isNotEmpty && _requiresPersonalInfo())
                          _buildDetailRow('Sex', widget.request.sex),
                        if (widget.request.birthdate != null)
                          _buildDetailRow(
                              'Birthdate',
                              DateFormat('MMMM dd, yyyy')
                                  .format(widget.request.birthdate!)),
                        _buildDetailRow(
                            'Fiscal Code', widget.request.fiscalCode),
                        // Show VAT Number if not empty
                        if (widget.request.vatNumber.isNotEmpty)
                          _buildDetailRow(
                              'VAT Number', widget.request.vatNumber),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Professional details
                    _buildSection(
                      title: 'Professional Information',
                      icon: Icons.work,
                      children: [
                        // UPDATED: Show all roles with colored chips
                        _buildRolesRow('Roles', widget.request.roleDisplayNames),
                        if (widget.request.specialty.isNotEmpty)
                          _buildDetailRow('Specialty', widget.request.specialty),
                        _buildDetailRow(
                            'City of Work', widget.request.cityOfWork),
                        // NEW: Show country of work
                        if (widget.request.countryOfWork != 'Italy')
                          _buildDetailRow(
                              'Country of Work', widget.request.countryOfWork),

                        // NEW: Show professional registration information
                        if (widget.request.requiresProfessionalRegistration) ...[
                          const SizedBox(height: 8),
                          // CURRENT: certification type + issuing institution
                          if (widget.request.registrationEntityTypeLabel != null)
                            _buildDetailRow('Certification Type',
                                widget.request.registrationEntityTypeLabel!),
                          if (widget.request.registrationValue != null)
                            _buildDetailRow('Issuing Institution',
                                widget.request.registrationValue!),
                          // LEGACY documents
                          if (widget.request.numeroIscrizioneAlbo != null)
                            _buildDetailRow('Registration (Albo)', widget.request.numeroIscrizioneAlbo!),
                          if (widget.request.numeroIscrizioneEnte != null)
                            _buildDetailRow('Registration (Ente)', widget.request.numeroIscrizioneEnte!),
                          if (widget.request.issuer.isNotEmpty)
                            _buildDetailRow('Qualification Issuer', widget.request.issuer),
                          if (widget.request.areaOfInterest != null && widget.request.areaOfInterest!.isNotEmpty)
                            _buildDetailRow('Area of Interest', widget.request.areaOfInterest!),
                          if (widget.request.qualificationValidity != null)
                            _buildDetailRow('Qualification Validity',
                                DateFormat('MMMM dd, yyyy').format(widget.request.qualificationValidity!)),
                          // NEW: Show professional validation status
                          _buildValidationStatusRow(),
                        ],

                        // NEW: Show hourly fees if set
                        if (widget.request.hasHourlyFeesSet)
                          _buildDetailRow('Hourly Fees', widget.request.formattedHourlyFees),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Contact & Location details
                    _buildSection(
                      title: 'Contact & Location',
                      icon: Icons.contact_mail,
                      children: [
                        _buildDetailRow('Email', widget.request.email),
                        _buildDetailRow('Phone', widget.request.phoneNumber),
                        if (widget.request.address.isNotEmpty)
                          _buildDetailRow('Address', widget.request.address),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Additional Information
                    _buildSection(
                      title: 'Additional Information',
                      icon: Icons.info_outline,
                      children: [
                        _buildLanguagesRow(
                            'Languages Spoken', widget.request.languagesSpoken),
                        _buildDetailRow(
                            'Request Date',
                            DateFormat('MMMM dd, yyyy \'at\' HH:mm')
                                .format(widget.request.requestedAt)),
                      ],
                    ),

                    // Show processing info if applicable
                    if (widget.request.status != 'pending') ...[
                      const SizedBox(height: 16),
                      _buildProcessingInfoSection(),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(),

            // Action buttons - UPDATED: Check professional validation
            if (widget.request.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context),
                      icon: const Icon(Icons.cancel,
                          color: CustomColors.rossoSimone),
                      label: const Text(
                        'Reject Request',
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      // UPDATED: Enable only if professional validation is complete
                      onPressed: widget.request.hasValidProfessionalRegistration
                          ? () => _showApprovalDialog(context)
                          : null,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        widget.request.hasValidProfessionalRegistration
                            ? 'Approve Request'
                            : 'Validation Required',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.request.hasValidProfessionalRegistration
                            ? CustomColors.verdeMare
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show current status for non-pending requests
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor().withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_getStatusIcon(), color: _getStatusColor()),
                    const SizedBox(width: 8),
                    Text(
                      'This request has been ${widget.request.status}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // NEW: Get primary role display name
  String _getPrimaryRoleDisplayName() {
    return widget.request.roleDisplayNames.isNotEmpty
        ? widget.request.roleDisplayNames.first
        : 'Professional';
  }

  // NEW: Check if request requires personal info
  bool _requiresPersonalInfo() {
    return widget.request.isNutritionist ||
        widget.request.isPsychologist ||
        widget.request.isPersonalTrainer;
  }

  String _getFullName() {
    // For organizations or if surname is empty, return just the name
    if (widget.request.surname.isEmpty) {
      return widget.request.name;
    }
    return '${widget.request.name} ${widget.request.surname}'.trim();
  }

  Color _getStatusColor() {
    switch (widget.request.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return CustomColors.rossoSimone;
      default: // 'pending' or other
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.request.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default: // 'pending' or other
        return Icons.pending_actions;
    }
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

  Widget _buildStatusSection(SignupRequest request) {
    Color statusColor = _getStatusColor();
    IconData statusIcon = _getStatusIcon();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${request.status.toUpperCase()}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted on ${DateFormat('MMMM dd, yyyy \'at\' HH:mm').format(request.requestedAt)}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomColors.perla.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomColors.verdeAbisso.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CustomColors.verdeAbisso, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    final displayValue = (value != null && value.isNotEmpty) ? value : 'Not provided';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, // Increased for longer labels
            child: Text(
              label + ':',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: (value != null && value.isNotEmpty) ? Colors.black87 : Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Build roles row with colored chips
  Widget _buildRolesRow(String label, List<String> roles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: roles.isNotEmpty
                ? Wrap(
              spacing: 8,
              runSpacing: 4,
              children: roles
                  .map((role) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _getRoleColor(role).withOpacity(0.3)),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ))
                  .toList(),
            )
                : Text(
              'Not provided',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesRow(String label, List<String> languages) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: languages.isNotEmpty
                ? Wrap(
              spacing: 8,
              runSpacing: 4,
              children: languages
                  .map((language) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CustomColors.verdeMare.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: CustomColors.verdeMare
                          .withOpacity(0.3)),
                ),
                child: Text(
                  language,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: CustomColors.verdeAbisso,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
                  .toList(),
            )
                : Text(
              'Not provided',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Build validation status row
  Widget _buildValidationStatusRow() {
    final isValid = widget.request.hasValidProfessionalRegistration;
    final color = isValid ? Colors.green : Colors.orange;
    final icon = isValid ? Icons.verified : Icons.warning;
    final text = isValid
        ? 'Professional validation complete'
        : 'Professional validation required';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingInfoSection() {
    if (widget.request.processedAt == null) return const SizedBox.shrink();

    return _buildSection(
      title: 'Processing Information',
      icon: Icons.admin_panel_settings,
      children: [
        _buildDetailRow(
          'Processed Date',
          DateFormat('MMMM dd, yyyy \'at\' HH:mm')
              .format(widget.request.processedAt!),
        ),
        if (widget.request.status == 'rejected' &&
            widget.request.rejectionReason != null &&
            widget.request.rejectionReason!.isNotEmpty)
          _buildDetailRow('Rejection Reason', widget.request.rejectionReason!),
        if (widget.request.temporaryPassword != null &&
            widget.request.temporaryPassword!.isNotEmpty)
          _buildDetailRow('Temp Password Sent', 'Yes'),
      ],
    );
  }

  void _showApprovalDialog(BuildContext context) {
    final signupRequestBloc = context.read<SignupRequestBloc>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Approve ${_getPrimaryRoleDisplayName()} Request',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approve registration for ${_getFullName()} (${widget.request.roleDisplayNames.join(', ')})?',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Set a temporary password:',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PasswordValidationWidget(
                    passwordController: _tempPasswordController,
                    onRegeneratePassword: () {
                      setState(() {
                        _tempPasswordController.text =
                            PasswordValidationHelper.generateValidatedPassword(
                                length: 12);
                      });
                    },
                    showPasswordRequirements: false,
                    helperText:
                    'User will be required to change on first login',
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
                            context, _tempPasswordController.text.trim())) {
                          return;
                        }

                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pop();

                        signupRequestBloc.add(
                          ApproveSignupRequestWithPassword(
                            id: widget.request.id,
                            temporaryPassword:
                            _tempPasswordController.text.trim(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'Approve & Send Credentials',
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
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    final signupRequestBloc = context.read<SignupRequestBloc>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Reject ${_getPrimaryRoleDisplayName()} Request',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: CustomColors.verdeAbisso,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject registration for ${_getFullName()} (${widget.request.roleDisplayNames.join(', ')})?',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  border: OutlineInputBorder(),
                  hintText:
                  'e.g., Incomplete documentation, Invalid credentials...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'An email notification will be sent to the applicant with the rejection reason.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
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
                    if (reasonController.text.trim().isEmpty) {
                      context.showErrorAlert(
                          'Please provide a reason for rejection');
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();

                    signupRequestBloc.add(
                      RejectSignupRequestWithReason(
                        id: widget.request.id,
                        reason: reasonController.text.trim(),
                      ),
                    );
                  },
                  icon:
                  const Icon(Icons.cancel, color: CustomColors.rossoSimone),
                  label: const Text(
                    'Reject & Notify',
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
        );
      },
    );
  }
}