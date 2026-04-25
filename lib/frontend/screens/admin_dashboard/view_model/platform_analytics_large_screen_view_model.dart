import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../backend/bloc/platform_analytics_bloc.dart';
import '../../../../backend/models/doctor/doctor_model.dart';
import '../../../../backend/models/signup_request_model.dart';
import '../../../../backend/repositories/platform_analytics_repository.dart';
import '../../../../shared/utils/colors.dart';

class PlatformAnalyticsLargeScreenViewModel extends StatelessWidget {
  const PlatformAnalyticsLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformAnalyticsBloc, PlatformAnalyticsState>(
      builder: (context, state) {
        if (state is PlatformAnalyticsLoading ||
            state is PlatformAnalyticsInitial) {
          return const Center(
            child: CircularProgressIndicator(color: CustomColors.verdeAbisso),
          );
        }
        if (state is PlatformAnalyticsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: CustomColors.rossoSimone, size: 48),
                const SizedBox(height: 16),
                Text(state.message,
                    style: const TextStyle(fontFamily: 'Montserrat')),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context
                      .read<PlatformAnalyticsBloc>()
                      .add(LoadPlatformAnalytics()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          );
        }
        if (state is PlatformAnalyticsLoaded) {
          return _Content(data: state.data);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  final PlatformAnalyticsData data;

  const _Content({required this.data});

  // ── Signup request helpers ─────────────────────────────────────────────────

  List<SignupRequest> get _allRequests => data.requests;
  List<SignupRequest> get _pending =>
      _allRequests.where((r) => r.status == 'pending').toList();
  List<SignupRequest> get _approved =>
      _allRequests.where((r) => r.status == 'approved').toList();
  List<SignupRequest> get _rejected =>
      _allRequests.where((r) => r.status == 'rejected').toList();

  List<SignupRequest> get _backlog {
    final threshold = DateTime.now().subtract(const Duration(days: 7));
    return _pending
        .where((r) => r.requestedAt.isBefore(threshold))
        .toList()
      ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
  }

  double get _approvalRate =>
      _allRequests.isEmpty ? 0 : _approved.length / _allRequests.length;

  /// Top 5 motivi di rifiuto raggruppati per testo
  List<MapEntry<String, int>> get _topRejectionReasons {
    final counts = <String, int>{};
    for (final r in _rejected) {
      final reason = (r.rejectionReason ?? '').trim();
      if (reason.isEmpty) continue;
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // ── Doctor helpers ─────────────────────────────────────────────────────────

  List<Doctor> get _doctors => data.doctors;

  int get _setupCompleted =>
      _doctors.where((d) => d.hasCompletedServiceSetup).length;

  int get _setupIncomplete =>
      _doctors.where((d) => !d.hasCompletedServiceSetup).length;

  List<Doctor> get _incompleteSetupDoctors {
    final list = _doctors.where((d) => !d.hasCompletedServiceSetup).toList();
    list.sort((a, b) {
      final dateA = a.signupApprovalDate ?? DateTime.now();
      final dateB = b.signupApprovalDate ?? DateTime.now();
      return dateA.compareTo(dateB);
    });
    return list.take(8).toList();
  }

  int get _multiRoleCount =>
      _doctors.where((d) => d.roles.length > 1).length;

  /// Combinazioni di ruoli più comuni tra professionisti multi-ruolo
  List<MapEntry<String, int>> get _topRoleCombinations {
    final counts = <String, int>{};
    for (final d in _doctors.where((d) => d.roles.length > 1)) {
      final key = (List<String>.from(d.roles)..sort()).join(' + ');
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  /// Distribuzione tariffe per fascia, per ruolo
  Map<String, Map<String, int>> get _feesByRole {
    final roles = [
      Doctor.ROLE_NUTRITIONIST,
      Doctor.ROLE_PERSONAL_TRAINER,
      Doctor.ROLE_PSYCHOLOGIST,
    ];
    final bands = ['€0 – €30', '€31 – €60', '€61 – €100', 'Oltre €100'];
    final result = <String, Map<String, int>>{};
    for (final role in roles) {
      final map = {for (final b in bands) b: 0};
      for (final d in _doctors.where((d) => d.roles.contains(role))) {
        final fee = d.hourlyFees;
        if (fee <= 30) {
          map['€0 – €30'] = map['€0 – €30']! + 1;
        } else if (fee <= 60) {
          map['€31 – €60'] = map['€31 – €60']! + 1;
        } else if (fee <= 100) {
          map['€61 – €100'] = map['€61 – €100']! + 1;
        } else {
          map['Oltre €100'] = map['Oltre €100']! + 1;
        }
      }
      result[role] = map;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics Piattaforma',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.verdeAbisso,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Operatività, professionisti e qualità del catalogo',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: () => context
                      .read<PlatformAnalyticsBloc>()
                      .add(LoadPlatformAnalytics()),
                  icon: const Icon(Icons.refresh,
                      color: CustomColors.verdeAbisso),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Sezione Richieste ────────────────────────────────────────────
            _sectionHeader('Richieste di iscrizione', Icons.app_registration),
            const SizedBox(height: 16),

            // KPI richieste
            Row(
              children: [
                Expanded(child: _kpiCard('Totali', '${_allRequests.length}', Icons.list_alt, CustomColors.verdeAbisso)),
                Expanded(child: _kpiCard('Pending', '${_pending.length}', Icons.pending_actions, Colors.orange)),
                Expanded(child: _kpiCard('Approvate', '${_approved.length}', Icons.check_circle_outline, const Color(0xFF4CAF50))),
                Expanded(child: _kpiCard('Rifiutate', '${_rejected.length}', Icons.cancel_outlined, CustomColors.rossoSimone)),
                Expanded(child: _kpiCard('Tasso approvazione', '${(_approvalRate * 100).round()}%', Icons.percent, CustomColors.verdeMare)),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _backlogSection()),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: _rejectionReasonsSection()),
              ],
            ),

            const SizedBox(height: 32),

            // ── Sezione Professionisti ───────────────────────────────────────
            _sectionHeader('Professionisti', Icons.medical_services_outlined),
            const SizedBox(height: 16),

            // KPI professionisti
            Row(
              children: [
                Expanded(child: _kpiCard('Totali', '${_doctors.length}', Icons.people_outline, CustomColors.verdeAbisso)),
                Expanded(child: _kpiCard('Setup completato', '$_setupCompleted', Icons.task_alt, const Color(0xFF4CAF50))),
                Expanded(child: _kpiCard('Setup incompleto', '$_setupIncomplete', Icons.pending_outlined, Colors.orange)),
                Expanded(child: _kpiCard('Multi-ruolo', '$_multiRoleCount', Icons.account_tree_outlined, Colors.purple)),
                Expanded(child: _kpiCard('% setup ok', _doctors.isEmpty ? 'N/D' : '${((_setupCompleted / _doctors.length) * 100).round()}%', Icons.percent, CustomColors.verdeMare)),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _feesSection()),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _multiRoleSection()),
              ],
            ),

            const SizedBox(height: 16),

            _incompleteSetupSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Backlog ─────────────────────────────────────────────────────────────────

  Widget _backlogSection() {
    return _card(
      title: 'Backlog — in attesa da oltre 7 giorni',
      icon: Icons.hourglass_top,
      iconColor: _backlog.isEmpty ? const Color(0xFF4CAF50) : Colors.orange,
      child: _backlog.isEmpty
          ? _emptyRow('Nessuna richiesta in backlog')
          : Column(
              children: _backlog.take(6).map((r) {
                final days = DateTime.now()
                    .difference(r.requestedAt)
                    .inDays;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: days > 14
                              ? CustomColors.rossoSimone.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.schedule,
                          size: 18,
                          color: days > 14
                              ? CustomColors.rossoSimone
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.name} ${r.surname}',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              r.roleDisplayNames.join(', '),
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: days > 14
                              ? CustomColors.rossoSimone.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$days gg',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: days > 14
                                ? CustomColors.rossoSimone
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Motivi di rifiuto ───────────────────────────────────────────────────────

  Widget _rejectionReasonsSection() {
    final reasons = _topRejectionReasons;
    final maxCount =
        reasons.isEmpty ? 1 : reasons.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'Motivi di rifiuto più frequenti',
      icon: Icons.cancel_outlined,
      iconColor: CustomColors.rossoSimone,
      child: _rejected.isEmpty
          ? _emptyRow('Nessuna richiesta rifiutata')
          : reasons.isEmpty
              ? _emptyRow('Nessun motivo registrato')
              : Column(
                  children: reasons.map((entry) {
                    final pct = entry.value / maxCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${entry.value}×',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      CustomColors.rossoSimone),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  // ─── Tariffe per ruolo ───────────────────────────────────────────────────────

  Widget _feesSection() {
    final roleDefs = [
      (role: Doctor.ROLE_NUTRITIONIST,     label: 'Prof. salute alimentare', color: const Color(0xFF4CAF50)),
      (role: Doctor.ROLE_PERSONAL_TRAINER, label: 'Prof. salute motoria',    color: const Color(0xFFFF9800)),
      (role: Doctor.ROLE_PSYCHOLOGIST,     label: 'Prof. salute mentale',    color: const Color(0xFF9C27B0)),
    ];

    final bandColors = [
      const Color(0xFF81C784),
      const Color(0xFF64B5F6),
      const Color(0xFFFFB74D),
      const Color(0xFFE57373),
    ];

    return _card(
      title: 'Distribuzione tariffe per ruolo',
      icon: Icons.euro_outlined,
      iconColor: Colors.amber.shade700,
      child: _doctors.isEmpty
          ? _emptyRow('Nessun professionista')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // legenda fasce
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    '€0 – €30', '€31 – €60', '€61 – €100', 'Oltre €100'
                  ].asMap().entries.map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: bandColors[e.key],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(e.value, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11)),
                    ],
                  )).toList(),
                ),
                const SizedBox(height: 16),
                ...roleDefs.map((rd) {
                  final fees = _feesByRole[rd.role] ?? {};
                  final total = fees.values.fold(0, (s, v) => s + v);
                  if (total == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: rd.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              rd.label,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($total professionisti)',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 14,
                            child: Row(
                              children: fees.entries.toList().asMap().entries
                                  .where((e) => e.value.value > 0)
                                  .map((e) {
                                final pct = e.value.value / total;
                                return Flexible(
                                  flex: (pct * 100).round(),
                                  child: Tooltip(
                                    message: '${e.value.key}: ${e.value.value} (${(pct * 100).round()}%)',
                                    child: Container(
                                      color: bandColors[e.key],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: fees.entries.toList().asMap().entries
                              .where((e) => e.value.value > 0)
                              .map((e) {
                            final pct = (e.value.value / total * 100).round();
                            return Expanded(
                              child: Text(
                                '$pct%',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // ─── Multi-ruolo ─────────────────────────────────────────────────────────────

  Widget _multiRoleSection() {
    final combos = _topRoleCombinations;

    String _shortLabel(String rawKey) {
      return rawKey
          .replaceAll('NUTRITIONIST', 'Alim.')
          .replaceAll('PERSONAL TRAINER', 'Motoria')
          .replaceAll('PSYCHOLOGIST', 'Mentale');
    }

    return _card(
      title: 'Multi-ruolo',
      icon: Icons.account_tree_outlined,
      iconColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Singolo vs multi-ruolo
          _barRow(
            label: 'Singolo ruolo',
            count: _doctors.length - _multiRoleCount,
            pct: _doctors.isEmpty ? 0 : (_doctors.length - _multiRoleCount) / _doctors.length,
            color: CustomColors.verdeAbisso,
          ),
          _barRow(
            label: 'Multi-ruolo',
            count: _multiRoleCount,
            pct: _doctors.isEmpty ? 0 : _multiRoleCount / _doctors.length,
            color: Colors.purple,
          ),
          if (combos.isNotEmpty) ...[
            const Divider(height: 20),
            const Text(
              'Combinazioni più comuni',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            ...combos.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _shortLabel(e.key),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  // ─── Setup incompleto ────────────────────────────────────────────────────────

  Widget _incompleteSetupSection() {
    final list = _incompleteSetupDoctors;
    if (list.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Professionisti senza setup servizi completato',
      icon: Icons.pending_outlined,
      iconColor: Colors.orange,
      child: Column(
        children: [
          // Progress bar setup
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Setup completato: $_setupCompleted / ${_doctors.length}',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _doctors.isEmpty
                                ? '0%'
                                : '${((_setupCompleted / _doctors.length) * 100).round()}%',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: CustomColors.verdeMare,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _doctors.isEmpty
                              ? 0
                              : _setupCompleted / _doctors.length,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              CustomColors.verdeMare),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nome',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Ruoli',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'Approvato il',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          ...list.map((d) {
            final approvalLabel = d.signupApprovalDate != null
                ? DateFormat('dd/MM/yyyy').format(d.signupApprovalDate!)
                : '—';
            final roleLabels = d.roles.map(_roleLabel).join(', ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d.name} ${d.surname}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      roleLabels,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      approvalLabel,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: CustomColors.verdeAbisso, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CustomColors.verdeAbisso,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[600]),
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int count,
    required double pct,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text('$count  (${(pct * 100).round()}%)',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              color: Colors.grey[400], size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey[500],
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case Doctor.ROLE_NUTRITIONIST:    return 'Prof. salute alimentare';
      case Doctor.ROLE_PERSONAL_TRAINER: return 'Prof. salute motoria';
      case Doctor.ROLE_PSYCHOLOGIST:    return 'Prof. salute mentale';
      default: return role;
    }
  }
}
