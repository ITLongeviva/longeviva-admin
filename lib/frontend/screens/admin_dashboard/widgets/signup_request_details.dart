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
                        // Utilizza primaryRoleDisplayName per il titolo principale
                        '${widget.request.primaryRoleDisplayName} Registration Request',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.verdeAbisso,
                        ),
                      ),
                      if (widget.request.roles.length > 1) // Mostra ruoli aggiuntivi se presenti
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Roles: ${widget.request.rolesFormatted}',
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
                        // Condiziona la visualizzazione di Sesso e Data di nascita
                        // in base alla presenza di ruoli che tipicamente li richiedono
                        // o se il campo è effettivamente compilato.
                        if (widget.request.sex.isNotEmpty && (widget.request.isDoctor || widget.request.isNutritionist || widget.request.isPersonalTrainer || widget.request.isPsychologist))
                          _buildDetailRow('Sex', widget.request.sex),
                        if (widget.request.birthdate != null)
                          _buildDetailRow(
                              'Birthdate',
                              DateFormat('MMMM dd, yyyy')
                                  .format(widget.request.birthdate!)),
                        _buildDetailRow(
                            'Fiscal Code', widget.request.fiscalCode),
                        // Mostra Partita IVA se non è vuota
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
                        _buildDetailRow('Roles', widget.request.rolesFormatted),
                        if (widget.request.specialty.isNotEmpty)
                          _buildDetailRow('Specialty', widget.request.specialty),
                        if (widget.request.organization.isNotEmpty)
                          _buildDetailRow(
                              'Organization', widget.request.organization),
                        // Mostra Ragione Sociale se non è vuota (tipico per Cliniche)
                        if (widget.request.ragioneSociale.isNotEmpty)
                          _buildDetailRow(
                              'Business Name', widget.request.ragioneSociale),
                        _buildDetailRow(
                            'City of Work', widget.request.cityOfWork),
                        _buildDetailRow(
                            'Country of Work', widget.request.countryOfWork),
                        // Mostra informazioni di registrazione professionale se rilevanti
                        if (widget.request.requiresProfessionalRegistration) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow('Professional Registration', widget.request.professionalRegistrationSummary),
                          if(widget.request.areaOfInterest != null && widget.request.areaOfInterest!.isNotEmpty)
                            _buildDetailRow('Area of Interest', widget.request.areaOfInterest!),
                          if(widget.request.qualificationValidity != null)
                            _buildDetailRow('Qualification Validity', DateFormat('MMMM dd, yyyy').format(widget.request.qualificationValidity!)),
                        ]
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Contact & Location details
                    _buildSection(
                      title: 'Contact & Location',
                      icon: Icons.contact_mail,
                      children: [
                        _buildDetailRow('Email', widget.request.email),
                        // `googleEmail` non è più presente nel modello SignupData fornito,
                        // quindi è stato rimosso dalla visualizzazione. Se necessario, riaggiungerlo.
                        // _buildDetailRow(
                        // 'Google Email', widget.request.googleEmail ?? 'Not provided'),
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

            // Action buttons
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
                      onPressed: () => _showApprovalDialog(context),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'Approve Request',
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

  String _getFullName() {
    // Se è una clinica o un'organizzazione, il "nome" è probabilmente il nome dell'entità.
    // Altrimenti, combina nome e cognome per le persone.
    if (widget.request.isClinic || widget.request.organization.isNotEmpty && widget.request.surname.isEmpty) {
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
        return Icons.pending_actions; // Changed for better clarity
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

  Widget _buildDetailRow(String label, String? value) { // Value can be null
    final displayValue = (value != null && value.isNotEmpty) ? value : 'Not provided';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Adjust as needed
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

  Widget _buildLanguagesRow(String label, List<String> languages) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Adjust as needed
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
            widget.request.rejectionReason!.isNotEmpty) // Check if not empty
          _buildDetailRow('Rejection Reason', widget.request.rejectionReason!),
        if (widget.request.temporaryPassword != null && widget.request.temporaryPassword!.isNotEmpty) // Check if not empty
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
                'Approve ${widget.request.primaryRoleDisplayName} Request',
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
                    'Approve registration for ${_getFullName()} (${widget.request.rolesFormatted})?',
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
            'Reject ${widget.request.primaryRoleDisplayName} Request',
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
                'Reject registration for ${_getFullName()} (${widget.request.rolesFormatted})?',
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
