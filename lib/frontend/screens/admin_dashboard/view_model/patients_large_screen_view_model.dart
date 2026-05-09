import 'dart:convert' show utf8;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../backend/bloc/patients_bloc.dart';
import '../../../../backend/models/patient_model.dart';
import '../../../../shared/utils/colors.dart';

class PatientsLargeScreenViewModel extends StatelessWidget {
  const PatientsLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatientsBloc, PatientsState>(
      builder: (context, state) {
        if (state is PatientsInitial || state is PatientsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: CustomColors.verdeAbisso),
          );
        }
        if (state is PatientsError) {
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
                  onPressed: () =>
                      context.read<PatientsBloc>().add(LoadPatients()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          );
        }
        if (state is PatientsLoaded) {
          return _PatientsContent(patients: state.patients);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _PatientsContent extends StatefulWidget {
  final List<Patient> patients;

  const _PatientsContent({required this.patients});

  @override
  State<_PatientsContent> createState() => _PatientsContentState();
}

class _PatientsContentState extends State<_PatientsContent> {
  String? _sexFilter;
  String? _ageFilter;
  bool? _onboardingFilter;
  String _nameSearch = '';
  late TextEditingController _searchController;
  String _sortBy = 'name';
  bool _sortAsc = true;
  String _viewMode = 'lista';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _ageOf(Patient p) {
    if (p.birthdate == null) return -1;
    final now = DateTime.now();
    int age = now.year - p.birthdate!.year;
    if (now.month < p.birthdate!.month ||
        (now.month == p.birthdate!.month && now.day < p.birthdate!.day)) {
      age--;
    }
    return age;
  }

  String _sexNorm(Patient p) {
    final s = p.sex.trim().toUpperCase();
    if (s == 'M') return 'M';
    if (s == 'F') return 'F';
    return 'N.D.';
  }

  bool _matchesAge(Patient p) {
    if (_ageFilter == null) return true;
    final age = _ageOf(p);
    if (age < 0) return false;
    switch (_ageFilter) {
      case '<18':
        return age < 18;
      case '18–30':
        return age >= 18 && age <= 30;
      case '31–50':
        return age >= 31 && age <= 50;
      case '>50':
        return age > 50;
      default:
        return true;
    }
  }

  List<Patient> get _filtered {
    var list = widget.patients.where((p) {
      if (_sexFilter != null && _sexNorm(p) != _sexFilter) return false;
      if (!_matchesAge(p)) return false;
      if (_onboardingFilter != null &&
          p.hasCompletedOnboarding != _onboardingFilter) return false;
      if (_nameSearch.isNotEmpty) {
        final q = _nameSearch.toLowerCase();
        final full = '${p.name} ${p.surname}'.toLowerCase();
        final email = p.email.toLowerCase();
        if (!full.contains(q) && !email.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'age':
          final ageA = _ageOf(a);
          final ageB = _ageOf(b);
          cmp = ageA.compareTo(ageB);
          break;
        case 'date':
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        default:
          cmp = '${a.surname} ${a.name}'
              .toLowerCase()
              .compareTo('${b.surname} ${b.name}'.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _sexFilter = null;
      _ageFilter = null;
      _onboardingFilter = null;
      _nameSearch = '';
      _searchController.clear();
      _sortBy = 'name';
      _sortAsc = true;
    });
  }

  bool get _hasActiveFilters =>
      _sexFilter != null ||
      _ageFilter != null ||
      _onboardingFilter != null ||
      _nameSearch.isNotEmpty;

  List<MapEntry<String, int>> get _topConditions {
    final map = <String, int>{};
    for (final p in widget.patients) {
      for (final c in p.conditions) {
        final norm = c.trim();
        if (norm.isNotEmpty) map[norm] = (map[norm] ?? 0) + 1;
      }
    }
    return (map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .toList();
  }

  List<MapEntry<String, int>> get _topPatientCities {
    final map = <String, int>{};
    for (final p in widget.patients) {
      final c = p.cityOfResidence.trim();
      if (c.isNotEmpty) map[c] = (map[c] ?? 0) + 1;
    }
    return (map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();
  }

  void _exportCsv(List<Patient> patients) {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln(
        'Cognome,Nome,Email,Sesso,Età,Città,"Dottore assegnato","Onboarding completato","Iscritto il"');

    for (final p in patients) {
      final age = _ageOf(p);
      final ageStr = age >= 0 ? '$age' : 'N.D.';
      final doctorStr = p.assignedDoctorId != null ? 'Sì' : 'No';
      final onboardingStr = p.hasCompletedOnboarding ? 'Sì' : 'No';
      final dateStr = p.createdAt != null
          ? DateFormat('dd/MM/yyyy').format(p.createdAt!)
          : '';

      buffer.writeln([
        esc(p.surname),
        esc(p.name),
        esc(p.email),
        esc(_sexNorm(p)),
        esc(ageStr),
        esc(p.cityOfResidence),
        esc(doctorStr),
        esc(onboardingStr),
        esc(dateStr),
      ].join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'pazienti_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── Clinical Insights ────────────────────────────────────────────────────────

  Widget _clinicalInsightsSection() {
    final all = widget.patients;
    final total = all.length;
    if (total == 0) return const SizedBox.shrink();

    final conditions = _topConditions;
    final cities = _topPatientCities;
    final withDoctor = all.where((p) => p.assignedDoctorId != null).length;
    final onboarded = all.where((p) => p.hasCompletedOnboarding).length;

    final maxCondition = conditions.isEmpty
        ? 1
        : conditions.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxCity = cities.isEmpty
        ? 1
        : cities.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Insight Clinici',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Dato anonimizzato',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    color: Colors.purple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // KPI mini-row
        Row(
          children: [
            Expanded(
              child: _kpi(
                '$total',
                'Pazienti totali',
                Icons.people_outline,
                CustomColors.verdeAbisso,
              ),
            ),
            Expanded(
              child: _kpi(
                total == 0
                    ? '—'
                    : '${(withDoctor / total * 100).round()}%',
                'Con dottore assegnato',
                Icons.medical_services_outlined,
                CustomColors.verdeMare,
              ),
            ),
            Expanded(
              child: _kpi(
                total == 0
                    ? '—'
                    : '${(onboarded / total * 100).round()}%',
                'Onboarding completato',
                Icons.task_alt,
                const Color(0xFF4CAF50),
              ),
            ),
            Expanded(
              child: _kpi(
                '${conditions.length}',
                'Condizioni distinte rilevate',
                Icons.health_and_safety_outlined,
                Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Charts row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conditions.isNotEmpty)
              Expanded(
                flex: 6,
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.health_and_safety_outlined,
                              color: Colors.purple, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Condizioni più comuni',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                          ),
                          Text(
                            'Su ${total} pazienti',
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...conditions.map((e) {
                        return _barRow(
                          e.key,
                          e.value,
                          maxCondition,
                          Colors.purple,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            if (conditions.isNotEmpty && cities.isNotEmpty)
              const SizedBox(width: 16),
            if (cities.isNotEmpty)
              Expanded(
                flex: 4,
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_city_outlined,
                              color: CustomColors.verdeAbisso, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Distribuzione geografica',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: CustomColors.verdeAbisso,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...cities.map((e) => _barRow(
                            e.key,
                            e.value,
                            maxCity,
                            CustomColors.verdeTropicale,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const Divider(height: 40),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _clinicalInsightsSection(),
          const SizedBox(height: 8),
          _churnRiskSection(),
          const SizedBox(height: 8),
          _subMenu(),
          const SizedBox(height: 16),
          if (_viewMode == 'lista') ...[
          _filterSection(),
          const SizedBox(height: 20),
          _kpiRow(filtered),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _bySexChart(filtered)),
              const SizedBox(width: 16),
              Expanded(child: _byAgeChart(filtered)),
              const SizedBox(width: 16),
              Expanded(child: _byMonthChart(widget.patients)),
            ],
          ),
          const SizedBox(height: 20),
          _patientTable(filtered),
          ] else
            _clusterView(),
        ],
      ),
    );
  }

  // ── Filter section ───────────────────────────────────────────────────────────

  Widget _filterSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome, cognome o email…',
                    hintStyle: const TextStyle(
                        fontFamily: 'Montserrat', fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, color: CustomColors.verdeAbisso),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CustomColors.verdeMare),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CustomColors.verdeAbisso),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _nameSearch = v),
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear,
                      size: 16, color: CustomColors.rossoSimone),
                  label: const Text(
                    'Resetta filtri',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: CustomColors.rossoSimone,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh,
                    size: 18, color: CustomColors.verdeMare),
                tooltip: 'Ricarica dati',
                onPressed: () =>
                    context.read<PatientsBloc>().add(LoadPatients()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _filterRow(
            'Sesso',
            ['M', 'F', 'N.D.'].map((v) => _singleChip(v, _sexFilter, (sel) {
              setState(() => _sexFilter = sel);
            })).toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            'Età',
            ['<18', '18–30', '31–50', '>50']
                .map((v) => _singleChip(v, _ageFilter, (sel) {
                      setState(() => _ageFilter = sel);
                    }))
                .toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            'Onboarding',
            [
              _boolChip('Completato', true, _onboardingFilter,
                  (v) => setState(() => _onboardingFilter = v)),
              _boolChip('Incompleto', false, _onboardingFilter,
                  (v) => setState(() => _onboardingFilter = v)),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────────────

  Widget _kpiRow(List<Patient> filtered) {
    final total = filtered.length;

    final ages = filtered
        .map(_ageOf)
        .where((a) => a >= 0)
        .toList();
    final avgAge = ages.isEmpty
        ? null
        : ages.fold(0, (s, a) => s + a) / ages.length;

    final withDoctorCount =
        filtered.where((p) => p.assignedDoctorId != null).length;

    final onboardingCount =
        filtered.where((p) => p.hasCompletedOnboarding).length;
    final pctOnboarding =
        total == 0 ? 0.0 : onboardingCount / total * 100;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final lastMonth = filtered
        .where((p) => p.createdAt != null && p.createdAt!.isAfter(cutoff))
        .length;

    return Row(
      children: [
        Expanded(
            child: _kpi('$total', 'Pazienti totali', Icons.people_outline,
                CustomColors.verdeAbisso)),
        Expanded(
            child: _kpi(
                avgAge == null ? 'N/D' : avgAge.toStringAsFixed(1),
                'Età media',
                Icons.cake_outlined,
                CustomColors.verdeMare)),
        Expanded(
            child: _kpi(
                total == 0 ? '—' : '$withDoctorCount',
                'Con dottore assegnato',
                Icons.medical_services_outlined,
                const Color(0xFF4CAF50))),
        Expanded(
            child: _kpi('${pctOnboarding.round()}%', 'Onboarding completato',
                Icons.task_alt, Colors.orange)),
        Expanded(
            child: _kpi('$lastMonth', 'Iscritti ultimo mese',
                Icons.calendar_today_outlined, Colors.purple)),
      ],
    );
  }

  // ── Charts ───────────────────────────────────────────────────────────────────

  Widget _bySexChart(List<Patient> filtered) {
    final total = filtered.length;
    final counts = <String, int>{'M': 0, 'F': 0, 'N.D.': 0};
    for (final p in filtered) {
      counts[_sexNorm(p)] = (counts[_sexNorm(p)] ?? 0) + 1;
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Distribuzione per sesso'),
          const SizedBox(height: 16),
          _barRow('M', counts['M']!, total, const Color(0xFF42A5F5)),
          _barRow('F', counts['F']!, total, const Color(0xFFEC407A)),
          _barRow('N.D.', counts['N.D.']!, total, Colors.grey),
        ],
      ),
    );
  }

  Widget _byAgeChart(List<Patient> filtered) {
    final bands = ['<18', '18–30', '31–50', '>50'];
    final colors = [
      Colors.teal,
      CustomColors.verdeMare,
      CustomColors.verdeAbisso,
      Colors.indigo,
    ];
    final counts = <String, int>{};
    for (final b in bands) {
      counts[b] = 0;
    }
    for (final p in filtered) {
      final age = _ageOf(p);
      if (age < 0) continue;
      if (age < 18) {
        counts['<18'] = counts['<18']! + 1;
      } else if (age <= 30) {
        counts['18–30'] = counts['18–30']! + 1;
      } else if (age <= 50) {
        counts['31–50'] = counts['31–50']! + 1;
      } else {
        counts['>50'] = counts['>50']! + 1;
      }
    }
    final knownTotal =
        counts.values.fold(0, (s, v) => s + v);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Distribuzione per età'),
          const SizedBox(height: 16),
          ...bands.asMap().entries.map((e) => _barRow(
                e.value,
                counts[e.value]!,
                knownTotal == 0 ? 1 : knownTotal,
                colors[e.key],
              )),
        ],
      ),
    );
  }

  Widget _byMonthChart(List<Patient> allPatients) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return d;
    });

    final counts = <String, int>{};
    for (final m in months) {
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      counts[key] = 0;
    }

    for (final p in allPatients) {
      if (p.createdAt == null) continue;
      final key =
          '${p.createdAt!.year}-${p.createdAt!.month.toString().padLeft(2, '0')}';
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      }
    }

    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Iscrizioni (ultimi 6 mesi)'),
          const SizedBox(height: 16),
          ...months.map((m) {
            final key =
                '${m.year}-${m.month.toString().padLeft(2, '0')}';
            final count = counts[key] ?? 0;
            final label = DateFormat('MMM yy', 'it').format(m);
            return _barRow(
              label,
              count,
              maxCount == 0 ? 1 : maxCount,
              CustomColors.verdeTropicale,
            );
          }),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _patientTable(List<Patient> filtered) {
    final rows = filtered.take(100).toList();

    void toggleSort(String key) {
      setState(() {
        if (_sortBy == key) {
          _sortAsc = !_sortAsc;
        } else {
          _sortBy = key;
          _sortAsc = true;
        }
      });
    }

    Widget sortHeader(String label, String key, int flex) {
      final active = _sortBy == key;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          onTap: () => toggleSort(key),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? CustomColors.verdeAbisso
                      : Colors.grey[700],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: CustomColors.verdeAbisso,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chartTitle('Pazienti (${filtered.length})'),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _exportCsv(filtered),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Esporta CSV'),
                style: TextButton.styleFrom(
                    foregroundColor: CustomColors.verdeAbisso),
              ),
              const Spacer(),
              if (filtered.length > 100)
                Text(
                  'Visualizzati: 100 di ${filtered.length}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CustomColors.mentaFredda.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                sortHeader('Nome', 'name', 3),
                sortHeader('Sesso', 'sex', 1),
                sortHeader('Età', 'age', 1),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Città',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Dottore',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Onboarding',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                sortHeader('Iscritto il', 'date', 2),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nessun paziente trovato',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final age = _ageOf(p);
              final ageLabel = age >= 0 ? '$age' : '—';
              final dateLabel = p.createdAt != null
                  ? DateFormat('dd/MM/yyyy').format(p.createdAt!)
                  : '—';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${p.surname} ${p.name}'.trim(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        _sexNorm(p),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        ageLabel,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.cityOfResidence.isEmpty ? '—' : p.cityOfResidence,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Icon(
                        p.assignedDoctorId != null
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: p.assignedDoctorId != null
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade400,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Icon(
                        p.hasCompletedOnboarding
                            ? Icons.task_alt
                            : Icons.pending_outlined,
                        size: 18,
                        color: p.hasCompletedOnboarding
                            ? const Color(0xFF4CAF50)
                            : Colors.orange,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Widget _kpi(String value, String label, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
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
                      color: Colors.grey[600],
                    ),
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

  Widget _card({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _chartTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: CustomColors.verdeAbisso,
      ),
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(String label, List<Widget> chips) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleChip(
    String label,
    String? current,
    void Function(String?) onChange,
  ) {
    final selected = current == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) => onChange(selected ? null : label),
      selectedColor: CustomColors.verdeAbisso,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? CustomColors.verdeAbisso : Colors.grey.shade300,
      ),
    );
  }

  Widget _boolChip(
    String label,
    bool value,
    bool? current,
    void Function(bool?) onChange,
  ) {
    final selected = current == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) => onChange(selected ? null : value),
      selectedColor: CustomColors.verdeAbisso,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? CustomColors.verdeAbisso : Colors.grey.shade300,
      ),
    );
  }

  // ─── Churn risk ───────────────────────────────────────────────────────────────

  List<Patient> get _churnRiskPatients {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    final result = widget.patients.where((p) {
      if (p.assignedDoctorId != null) return false;
      if (p.lastActivityAt != null &&
          p.lastActivityAt!.isBefore(thirtyDaysAgo)) return true;
      if (p.lastActivityAt == null &&
          p.createdAt != null &&
          p.createdAt!.isBefore(fourteenDaysAgo)) return true;
      return false;
    }).toList();
    result.sort((a, b) {
      final aLast =
          a.lastActivityAt ?? a.createdAt ?? DateTime(2000);
      final bLast =
          b.lastActivityAt ?? b.createdAt ?? DateTime(2000);
      return aLast.compareTo(bLast);
    });
    return result;
  }

  Widget _churnRiskSection() {
    final atRisk = _churnRiskPatients;
    if (atRisk.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pazienti a rischio churn',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.verdeAbisso,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${atRisk.length}',
                  style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pazienti senza professionista assegnato e inattivi da oltre 30 giorni (o iscritti da 14+ giorni senza attività registrata).',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ...atRisk.take(8).map((p) {
            final now = DateTime.now();
            final lastRef = p.lastActivityAt ?? p.createdAt;
            final daysInactive = lastRef != null
                ? now.difference(lastRef).inDays
                : -1;
            final riskColor = daysInactive > 60
                ? CustomColors.rossoSimone
                : daysInactive > 30
                    ? Colors.orange
                    : Colors.amber;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: riskColor.withOpacity(0.15),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: riskColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.surname} ${p.name}'.trim(),
                          style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.cityOfResidence.isNotEmpty)
                          Text(
                            p.cityOfResidence,
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: p.conditions.isNotEmpty
                        ? Text(
                            p.conditions.take(2).join(', '),
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox(),
                  ),
                  if (daysInactive >= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$daysInactive gg inattivo',
                        style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: riskColor),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (atRisk.length > 8) ...[
            const SizedBox(height: 8),
            Text(
              '+ altri ${atRisk.length - 8} pazienti a rischio',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Sottomenu ────────────────────────────────────────────────────────────────

  Widget _subMenu() {
    final modes = [
      (key: 'lista',      label: 'Lista',         icon: Icons.list_alt_outlined),
      (key: 'condizione', label: 'Per condizione', icon: Icons.health_and_safety_outlined),
      (key: 'citta',      label: 'Per città',      icon: Icons.location_city_outlined),
      (key: 'eta',        label: 'Per età',        icon: Icons.cake_outlined),
      (key: 'stato',      label: 'Per stato',      icon: Icons.toggle_on_outlined),
      (key: 'cerchie',    label: 'Cerchie',         icon: Icons.bubble_chart_outlined),
    ];
    return Row(
      children: [
        Text(
          'Visualizza:',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: modes.map((m) {
            final sel = _viewMode == m.key;
            return GestureDetector(
              onTap: () => setState(() => _viewMode = m.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? CustomColors.verdeAbisso : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? CustomColors.verdeAbisso
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.icon,
                        size: 14,
                        color: sel ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Cluster view dispatcher ──────────────────────────────────────────────────

  Widget _clusterView() {
    switch (_viewMode) {
      case 'condizione': return _clusterByCondition();
      case 'citta':      return _clusterByCity();
      case 'eta':        return _clusterByAge();
      case 'stato':      return _clusterByStatus();
      case 'cerchie':    return _cerchieView();
      default:           return const SizedBox.shrink();
    }
  }

  // ─── Cluster by condition ─────────────────────────────────────────────────────

  Widget _clusterByCondition() {
    final conditionMap = <String, List<Patient>>{};
    for (final p in widget.patients) {
      if (p.conditions.isEmpty) {
        conditionMap
            .putIfAbsent('Nessuna condizione', () => [])
            .add(p);
      } else {
        for (final c in p.conditions) {
          final norm = c.trim();
          if (norm.isNotEmpty) {
            conditionMap.putIfAbsent(norm, () => []).add(p);
          }
        }
      }
    }
    final sorted = conditionMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return _clusterGrid([
      for (final e in sorted.take(12))
        (
          label: e.key,
          color: Colors.purple,
          icon: Icons.health_and_safety_outlined,
          members: e.value,
          total: widget.patients.length,
        ),
    ]);
  }

  // ─── Cluster by city ──────────────────────────────────────────────────────────

  Widget _clusterByCity() {
    final cityMap = <String, List<Patient>>{};
    for (final p in widget.patients) {
      final city = p.cityOfResidence.trim().isEmpty
          ? 'Non specificata'
          : p.cityOfResidence.trim();
      cityMap.putIfAbsent(city, () => []).add(p);
    }
    final sorted = cityMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return _clusterGrid([
      for (final e in sorted.take(12))
        (
          label: e.key,
          color: CustomColors.verdeTropicale,
          icon: Icons.location_city_outlined,
          members: e.value,
          total: widget.patients.length,
        ),
    ]);
  }

  // ─── Cluster by age ───────────────────────────────────────────────────────────

  Widget _clusterByAge() {
    final bands = [
      (label: 'Under 18', color: Colors.teal,             icon: Icons.child_care_outlined,  minAge: 0,  maxAge: 17),
      (label: '18 – 30',  color: const Color(0xFF4CAF50), icon: Icons.person_outline,        minAge: 18, maxAge: 30),
      (label: '31 – 50',  color: const Color(0xFF2196F3), icon: Icons.person,                minAge: 31, maxAge: 50),
      (label: '50+',      color: const Color(0xFF9C27B0), icon: Icons.person_3_outlined,     minAge: 51, maxAge: 999),
    ];
    return _clusterGrid([
      for (final b in bands)
        (
          label: b.label,
          color: b.color,
          icon: b.icon,
          members: widget.patients.where((p) {
            final age = _ageOf(p);
            return age >= b.minAge && age <= b.maxAge;
          }).toList(),
          total: widget.patients.length,
        ),
    ]);
  }

  // ─── Cluster by status ────────────────────────────────────────────────────────

  Widget _clusterByStatus() {
    final withDoc =
        widget.patients.where((p) => p.assignedDoctorId != null).toList();
    final withoutDoc =
        widget.patients.where((p) => p.assignedDoctorId == null).toList();
    final onboarded =
        widget.patients.where((p) => p.hasCompletedOnboarding).toList();
    final notOnboarded =
        widget.patients.where((p) => !p.hasCompletedOnboarding).toList();

    return _clusterGrid([
      (label: 'Con dottore assegnato',    color: const Color(0xFF4CAF50), icon: Icons.medical_services_outlined, members: withDoc,      total: widget.patients.length),
      (label: 'Senza dottore assegnato',  color: Colors.orange,           icon: Icons.person_search_outlined,    members: withoutDoc,   total: widget.patients.length),
      (label: 'Onboarding completato',    color: CustomColors.verdeMare,  icon: Icons.task_alt,                  members: onboarded,    total: widget.patients.length),
      (label: 'Onboarding incompleto',    color: Colors.grey,             icon: Icons.pending_outlined,          members: notOnboarded, total: widget.patients.length),
    ]);
  }

  // ─── Cluster grid & card ──────────────────────────────────────────────────────

  Map<String, String> _clusterStats(List<Patient> members) {
    if (members.isEmpty) return {};
    final now = DateTime.now();
    final ages = members
        .where((p) => p.birthdate != null)
        .map((p) {
          int age = now.year - p.birthdate!.year;
          if (now.month < p.birthdate!.month ||
              (now.month == p.birthdate!.month &&
                  now.day < p.birthdate!.day)) {
            age--;
          }
          return age;
        })
        .toList();
    final avgAgeStr = ages.isEmpty
        ? 'N/D'
        : '${(ages.fold(0, (s, a) => s + a) / ages.length).toStringAsFixed(0)} aa';
    final withDoc = members.where((p) => p.assignedDoctorId != null).length;
    final f = members.where((p) => p.sex.trim().toUpperCase() == 'F').length;
    final m = members.where((p) => p.sex.trim().toUpperCase() == 'M').length;
    return {
      'Età media': avgAgeStr,
      'Con dottore': '$withDoc/${members.length}',
      'F / M': '$f / $m',
    };
  }

  Widget _clusterGrid(
    List<({String label, Color color, IconData icon, List<Patient> members, int total})>
        clusters,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 200,
      ),
      itemCount: clusters.length,
      itemBuilder: (_, i) => _clusterCard(clusters[i]),
    );
  }

  Widget _clusterCard(
    ({String label, Color color, IconData icon, List<Patient> members, int total}) cluster,
  ) {
    final count = cluster.members.length;
    final pct = cluster.total == 0 ? 0.0 : count / cluster.total;
    final stats = _clusterStats(cluster.members);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showClusterDetail(cluster),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: cluster.color.withOpacity(0.08),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cluster.color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cluster.icon, color: cluster.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.label,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: CustomColors.verdeAbisso,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count paziente${count == 1 ? '' : 'i'}',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cluster.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cluster.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(cluster.color),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stats.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: stats.entries
                            .take(3)
                            .map(
                              (e) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    e.value,
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: CustomColors.verdeAbisso,
                                    ),
                                  ),
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Vedi dettagli',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            color: cluster.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 11, color: cluster.color),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClusterDetail(
    ({String label, Color color, IconData icon, List<Patient> members, int total}) cluster,
  ) {
    String search = '';
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = search.isEmpty
              ? cluster.members
              : cluster.members.where((p) {
                  final q = search.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      p.surname.toLowerCase().contains(q) ||
                      p.cityOfResidence.toLowerCase().contains(q);
                }).toList();
          final stats = _clusterStats(cluster.members);
          final pct = cluster.total == 0
              ? 0.0
              : cluster.members.length / cluster.total;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 720,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      color: cluster.color.withOpacity(0.08),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cluster.color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cluster.icon,
                                color: cluster.color, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cluster.label,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: CustomColors.verdeAbisso,
                                  ),
                                ),
                                Text(
                                  '${cluster.members.length} pazienti · ${(pct * 100).round()}% del totale',
                                  style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    // Stats row
                    if (stats.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        color: Colors.grey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: stats.entries
                              .map(
                                (e) => Column(
                                  children: [
                                    Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: CustomColors.verdeAbisso,
                                      ),
                                    ),
                                    Text(
                                      e.key,
                                      style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 11,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    // Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca per nome o città…',
                          prefixIcon: const Icon(Icons.search,
                              color: CustomColors.verdeAbisso),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setDialogState(() => search = v),
                      ),
                    ),
                    // Member list
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(ctx).size.height * 0.5,
                        ),
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text('Nessun risultato',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(
                                    24, 8, 24, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade100),
                                itemBuilder: (_, i) {
                                  final p = filtered[i];
                                  final age = _ageOf(p);
                                  final ageLabel =
                                      age >= 0 ? '$age aa' : '—';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: cluster.color
                                              .withOpacity(0.15),
                                          child: Text(
                                            p.name.isNotEmpty
                                                ? p.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.bold,
                                              color: cluster.color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${p.surname} ${p.name}'.trim(),
                                                style: const TextStyle(
                                                  fontFamily: 'Nunito',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                p.email,
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            _sexNorm(p),
                                            style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 12),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            ageLabel,
                                            style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 12),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            p.cityOfResidence.isEmpty
                                                ? '—'
                                                : p.cityOfResidence,
                                            style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (p.conditions.isNotEmpty)
                                          Expanded(
                                            flex: 2,
                                            child: Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: p.conditions
                                                  .take(2)
                                                  .map(
                                                    (c) => Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.purple
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        c,
                                                        style: const TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 10,
                                                          color: Colors.purple,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          )
                                        else
                                          const Expanded(flex: 2, child: SizedBox()),
                                        Tooltip(
                                          message: p.assignedDoctorId != null
                                              ? 'Dottore assegnato'
                                              : 'Nessun dottore',
                                          child: Icon(
                                            p.assignedDoctorId != null
                                                ? Icons.medical_services
                                                : Icons.person_search_outlined,
                                            size: 16,
                                            color: p.assignedDoctorId != null
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: p.hasCompletedOnboarding
                                              ? 'Onboarding completato'
                                              : 'Onboarding incompleto',
                                          child: Icon(
                                            p.hasCompletedOnboarding
                                                ? Icons.task_alt
                                                : Icons.pending_outlined,
                                            size: 16,
                                            color: p.hasCompletedOnboarding
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Cerchie di affinità ──────────────────────────────────────────────────────

  static const _bubbleColors = [
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.orange,
    Colors.cyan,
    Colors.deepPurple,
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.brown,
    Colors.blueGrey,
  ];

  Color _cerchiaColor(String condition) =>
      _bubbleColors[condition.hashCode.abs() % _bubbleColors.length];

  Widget _cerchieView() {
    final groups = <String, List<Patient>>{};

    for (final p in widget.patients) {
      final age = _ageOf(p);
      final ageGroup = age < 0
          ? 'N.D.'
          : age < 18
              ? 'Under 18'
              : age <= 30
                  ? '18–30'
                  : age <= 50
                      ? '31–50'
                      : '50+';

      if (p.conditions.isEmpty) {
        groups
            .putIfAbsent('Nessuna condizione·$ageGroup', () => [])
            .add(p);
      } else {
        for (final c in p.conditions) {
          final norm = c.trim();
          if (norm.isNotEmpty) {
            groups.putIfAbsent('$norm·$ageGroup', () => []).add(p);
          }
        }
      }
    }

    final cerchie = (groups.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length)))
        .where((e) => e.value.length >= 2)
        .take(24)
        .toList();

    if (cerchie.isEmpty) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Dati insufficienti — servono almeno 2 pazienti con la stessa condizione e fascia d\'età.',
              style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final maxCount = cerchie.first.value.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cerchie di affinità',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  Text(
                    'Pazienti raggruppati per condizione e fascia d\'età — la dimensione della cerchia è proporzionale al numero di pazienti nel gruppo. Tocca per i dettagli.',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Dato anonimizzato',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    color: Colors.purple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.start,
          children: cerchie.map((e) {
            final parts = e.key.split('·');
            final condition = parts[0];
            final ageGroup = parts.length > 1 ? parts[1] : '';
            final count = e.value.length;
            final size = 90.0 + (count / maxCount) * 90.0;
            final color = _cerchiaColor(condition);

            return GestureDetector(
              onTap: () =>
                  _showCerchiaDetail(condition, ageGroup, e.value, color),
              child: Tooltip(
                message: '$condition · $ageGroup · $count pazienti',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: color.withOpacity(0.45), width: 2),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: size > 140
                                  ? 26
                                  : size > 110
                                      ? 20
                                      : 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            condition,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: size > 130 ? 10 : 8,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            ageGroup,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 8,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chartTitle('Distribuzione delle cerchie (top 10)'),
              const SizedBox(height: 12),
              ...cerchie.take(10).map((e) {
                final parts = e.key.split('·');
                final condition = parts[0];
                final ageGroup = parts.length > 1 ? parts[1] : '';
                final color = _cerchiaColor(condition);
                return _barRow(
                    '$condition · $ageGroup', e.value.length, maxCount, color);
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showCerchiaDetail(
    String condition,
    String ageGroup,
    List<Patient> members,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final withDoc =
            members.where((p) => p.assignedDoctorId != null).length;
        final onboarded =
            members.where((p) => p.hasCompletedOnboarding).length;
        final active = members.where((p) => p.isActive).length;
        final f = members
            .where((p) => p.sex.trim().toUpperCase() == 'F')
            .length;
        final m = members
            .where((p) => p.sex.trim().toUpperCase() == 'M')
            .length;
        final stats = _clusterStats(members);

        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color.withOpacity(0.4), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${members.length}',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            condition,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: CustomColors.verdeAbisso,
                            ),
                          ),
                          Text(
                            'Fascia d\'età: $ageGroup · ${members.length} pazienti',
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _cerchiaStat(
                        '${members.length}', 'Pazienti nel gruppo', color),
                    _cerchiaStat('$withDoc / ${members.length}',
                        'Con dottore assegnato', const Color(0xFF4CAF50)),
                    _cerchiaStat('$onboarded / ${members.length}',
                        'Onboarding completato', Colors.teal),
                    _cerchiaStat(
                        stats['Età media'] ?? '—', 'Età media', Colors.indigo),
                    _cerchiaStat(
                        '$f F  /  $m M', 'Distribuzione sesso', Colors.pink),
                    _cerchiaStat('$active / ${members.length}',
                        'Account attivi', Colors.orange),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tutti i dati di questa cerchia sono anonimi. Nessuna informazione personale è esposta.',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cerchiaStat(String value, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
