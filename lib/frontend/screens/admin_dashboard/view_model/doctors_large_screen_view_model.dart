import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'package:intl/intl.dart';
import '../../../../backend/bloc/doctors_bloc.dart';
import '../../../../backend/models/doctor/doctor_model.dart';
import '../../../../shared/utils/colors.dart';

class DoctorsLargeScreenViewModel extends StatelessWidget {
  const DoctorsLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DoctorsBloc, DoctorsState>(
      builder: (context, state) {
        if (state is DoctorsLoading || state is DoctorsInitial) {
          return const Center(
            child: CircularProgressIndicator(color: CustomColors.verdeAbisso),
          );
        }
        if (state is DoctorsError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: CustomColors.rossoSimone),
            ),
          );
        }
        if (state is DoctorsLoaded) {
          return _DoctorsContent(doctors: state.doctors);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DoctorsContent extends StatefulWidget {
  final List<Doctor> doctors;
  const _DoctorsContent({required this.doctors});

  @override
  State<_DoctorsContent> createState() => _DoctorsContentState();
}

class _DoctorsContentState extends State<_DoctorsContent> {
  Set<String> _roleFilter = {};
  String? _sexFilter;
  String? _ageFilter;
  bool? _setupFilter;
  bool? _activeFilter;
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

  int _ageOf(Doctor d) {
    final now = DateTime.now();
    int age = now.year - d.birthdate.year;
    if (now.month < d.birthdate.month ||
        (now.month == d.birthdate.month && now.day < d.birthdate.day)) {
      age--;
    }
    return age;
  }

  String _sexNorm(Doctor d) {
    final s = d.sex.trim().toUpperCase();
    if (s == 'M' || s == 'MALE' || s == 'MASCHILE') return 'M';
    if (s == 'F' || s == 'FEMALE' || s == 'FEMMINILE') return 'F';
    return 'N.D.';
  }

  bool _matchesAge(Doctor d) {
    if (_ageFilter == null) return true;
    final age = _ageOf(d);
    switch (_ageFilter) {
      case '<30':
        return age < 30;
      case '30–40':
        return age >= 30 && age <= 40;
      case '41–50':
        return age >= 41 && age <= 50;
      case '>50':
        return age > 50;
      default:
        return true;
    }
  }

  List<Doctor> get _filtered {
    List<Doctor> list = widget.doctors.where((d) {
      if (_roleFilter.isNotEmpty && !_roleFilter.any((r) => d.roles.contains(r))) {
        return false;
      }
      if (_sexFilter != null && _sexNorm(d) != _sexFilter) return false;
      if (!_matchesAge(d)) return false;
      if (_setupFilter != null && d.hasCompletedServiceSetup != _setupFilter) {
        return false;
      }
      if (_activeFilter != null && d.isActive != _activeFilter) return false;
      if (_nameSearch.isNotEmpty) {
        final q = _nameSearch.toLowerCase();
        if (!d.name.toLowerCase().contains(q) &&
            !d.surname.toLowerCase().contains(q) &&
            !d.email.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'age':
          cmp = _ageOf(a).compareTo(_ageOf(b));
          break;
        case 'sex':
          cmp = _sexNorm(a).compareTo(_sexNorm(b));
          break;
        case 'fee':
          cmp = a.hourlyFees.compareTo(b.hourlyFees);
          break;
        case 'city':
          cmp = a.cityOfWork.compareTo(b.cityOfWork);
          break;
        case 'date':
          final da = a.signupApprovalDate;
          final db = b.signupApprovalDate;
          if (da == null && db == null) {
            cmp = 0;
          } else if (da == null) {
            cmp = 1;
          } else if (db == null) {
            cmp = -1;
          } else {
            cmp = da.compareTo(db);
          }
          break;
        default:
          cmp = a.surname.compareTo(b.surname);
          if (cmp == 0) cmp = a.name.compareTo(b.name);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _roleFilter = {};
      _sexFilter = null;
      _ageFilter = null;
      _setupFilter = null;
      _activeFilter = null;
      _nameSearch = '';
      _searchController.clear();
    });
  }

  bool get _hasActiveFilters =>
      _roleFilter.isNotEmpty ||
      _sexFilter != null ||
      _ageFilter != null ||
      _setupFilter != null ||
      _activeFilter != null ||
      _nameSearch.isNotEmpty;

  List<Doctor> get _expiringQualifications {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 90));
    return widget.doctors
        .where((d) =>
            d.qualificationValidity != null &&
            d.qualificationValidity!.isAfter(now) &&
            d.qualificationValidity!.isBefore(limit))
        .toList()
      ..sort((a, b) =>
          a.qualificationValidity!.compareTo(b.qualificationValidity!));
  }

  void _exportCsv(List<Doctor> doctors) {
    final buffer = StringBuffer();
    buffer.writeln('Cognome,Nome,Email,"Ruolo/i",Sesso,Età,Città,"Tariffa (€/h)","Setup completato","Iscritto il"');
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    for (final d in doctors) {
      final age = _ageOf(d);
      final roles = d.roles.map(_roleLabel).join('; ');
      final fee = d.hourlyFees == 0 ? 'N.D.' : d.hourlyFees.toStringAsFixed(0);
      final date = d.signupApprovalDate != null
          ? DateFormat('dd/MM/yyyy').format(d.signupApprovalDate!)
          : '';
      buffer.writeln([
        esc(d.surname), esc(d.name), esc(d.email), esc(roles),
        _sexNorm(d), '$age', esc(d.cityOfWork), fee,
        d.hasCompletedServiceSetup ? 'Sì' : 'No', date,
      ].join(','));
    }
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'dottori_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _expiringQualificationsCard(List<Doctor> expiring) {
    if (expiring.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Qualifiche in scadenza (prossimi 90 giorni)',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${expiring.length}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...expiring.take(10).map((d) {
            final daysLeft =
                d.qualificationValidity!.difference(DateTime.now()).inDays;
            final daysColor = daysLeft < 30
                ? CustomColors.rossoSimone
                : daysLeft < 60
                    ? const Color(0xFFFF9800)
                    : const Color(0xFFFFC107);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${d.surname} ${d.name}',
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                      flex: 3,
                      child: Wrap(
                          spacing: 4,
                          children: d.roles.map(_roleBadge).toList())),
                  Expanded(
                    flex: 2,
                    child: Text(
                      d.cityOfWork.isEmpty ? '—' : d.cityOfWork,
                      style:
                          const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(d.qualificationValidity!),
                      style:
                          const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '$daysLeft gg',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: daysColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (expiring.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'e altri ${expiring.length - 10}…',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = column;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _subMenu(),
          const SizedBox(height: 16),
          if (_viewMode == 'lista') ...[
            _expiringQualificationsCard(_expiringQualifications),
            const SizedBox(height: 16),
            _filterSection(),
            const SizedBox(height: 20),
            _kpiRow(filtered),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _byRoleChart(filtered)),
                const SizedBox(width: 16),
                Expanded(child: _bySexChart(filtered)),
                const SizedBox(width: 16),
                Expanded(child: _byAgeChart(filtered)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _byCityChart(filtered)),
                const SizedBox(width: 16),
                Expanded(child: _byFeeChart(filtered)),
              ],
            ),
            const SizedBox(height: 20),
            _doctorTable(filtered),
          ] else
            _clusterView(),
        ],
      ),
    );
  }

  Widget _filterSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: CustomColors.verdeAbisso),
              const SizedBox(width: 8),
              const Text(
                'Filtra dottori',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Azzera filtri'),
                  style: TextButton.styleFrom(
                    foregroundColor: CustomColors.rossoSimone,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: CustomColors.verdeMare),
                tooltip: 'Ricarica dati',
                onPressed: () => context.read<DoctorsBloc>().add(LoadDoctors()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cerca per nome, cognome o email…',
              prefixIcon: const Icon(Icons.search, color: CustomColors.verdeAbisso),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _nameSearch = v),
          ),
          const SizedBox(height: 12),
          _filterRow(
            label: 'Ruolo',
            chips: [
              _roleChip(Doctor.ROLE_NUTRITIONIST, Colors.green),
              _roleChip(Doctor.ROLE_PERSONAL_TRAINER, Colors.orange),
              _roleChip(Doctor.ROLE_PSYCHOLOGIST, Colors.purple),
            ],
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Sesso',
            chips: ['M', 'F', 'N.D.'].map((s) {
              final selected = _sexFilter == s;
              return FilterChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => setState(
                    () => _sexFilter = selected ? null : s),
                selectedColor: CustomColors.verdeMare.withOpacity(0.3),
                checkmarkColor: CustomColors.verdeAbisso,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Età',
            chips: ['<30', '30–40', '41–50', '>50'].map((a) {
              final selected = _ageFilter == a;
              return FilterChip(
                label: Text(a),
                selected: selected,
                onSelected: (_) => setState(
                    () => _ageFilter = selected ? null : a),
                selectedColor: CustomColors.verdeMare.withOpacity(0.3),
                checkmarkColor: CustomColors.verdeAbisso,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Setup',
            chips: [
              _boolChip('Completato', true, _setupFilter,
                  (v) => setState(() => _setupFilter = v)),
              _boolChip('Incompleto', false, _setupFilter,
                  (v) => setState(() => _setupFilter = v)),
            ],
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Account',
            chips: [
              _boolChip('Attivi', true, _activeFilter,
                  (v) => setState(() => _activeFilter = v)),
              _boolChip('Inattivi', false, _activeFilter,
                  (v) => setState(() => _activeFilter = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String role, Color color) {
    final selected = _roleFilter.contains(role);
    return FilterChip(
      label: Text(_roleLabel(role)),
      selected: selected,
      onSelected: (_) {
        setState(() {
          if (selected) {
            _roleFilter = Set.from(_roleFilter)..remove(role);
          } else {
            _roleFilter = Set.from(_roleFilter)..add(role);
          }
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : null),
    );
  }

  Widget _boolChip(String label, bool value, bool? current,
      void Function(bool?) onChanged) {
    final selected = current == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(selected ? null : value),
      selectedColor: CustomColors.verdeMare.withOpacity(0.3),
      checkmarkColor: CustomColors.verdeAbisso,
    );
  }

  Widget _filterRow({required String label, required List<Widget> chips}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
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
    );
  }

  Widget _kpiRow(List<Doctor> filtered) {
    final count = filtered.length;
    final avgAge = count == 0
        ? 0.0
        : filtered.map(_ageOf).reduce((a, b) => a + b) / count;
    final avgFee = count == 0
        ? 0.0
        : filtered.map((d) => d.hourlyFees).reduce((a, b) => a + b) / count;
    final setupPct = count == 0
        ? 0.0
        : filtered.where((d) => d.hasCompletedServiceSetup).length /
            count *
            100;
    final activePct = count == 0
        ? 0.0
        : filtered.where((d) => d.isActive).length / count * 100;

    return Row(
      children: [
        Expanded(
            child: _kpi('$count', 'Dottori totali', Icons.people,
                CustomColors.verdeAbisso)),
        const SizedBox(width: 12),
        Expanded(
            child: _kpi(avgAge.toStringAsFixed(1), 'Età media', Icons.cake,
                Colors.blueGrey)),
        const SizedBox(width: 12),
        Expanded(
            child: _kpi('€${avgFee.toStringAsFixed(0)}/h', 'Tariffa media',
                Icons.euro, Colors.indigo)),
        const SizedBox(width: 12),
        Expanded(
            child: _kpi('${setupPct.toStringAsFixed(0)}%', 'Setup completato',
                Icons.settings_suggest, Colors.teal)),
        const SizedBox(width: 12),
        Expanded(
            child: _kpi('${activePct.toStringAsFixed(0)}%', 'Account attivi',
                Icons.check_circle_outline, Colors.green)),
      ],
    );
  }

  Widget _kpi(String value, String label, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _byRoleChart(List<Doctor> list) {
    final total = list.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Per ruolo'),
          const SizedBox(height: 12),
          _barRow('Alimentare',
              list.where((d) => d.roles.contains(Doctor.ROLE_NUTRITIONIST)).length,
              total, Colors.green),
          _barRow('Motoria',
              list.where((d) => d.roles.contains(Doctor.ROLE_PERSONAL_TRAINER)).length,
              total, Colors.orange),
          _barRow('Mentale',
              list.where((d) => d.roles.contains(Doctor.ROLE_PSYCHOLOGIST)).length,
              total, Colors.purple),
        ],
      ),
    );
  }

  Widget _bySexChart(List<Doctor> list) {
    final total = list.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Per sesso'),
          const SizedBox(height: 12),
          _barRow('Maschile',
              list.where((d) => _sexNorm(d) == 'M').length, total, Colors.blue),
          _barRow('Femminile',
              list.where((d) => _sexNorm(d) == 'F').length, total, Colors.pink),
          _barRow('Non specificato',
              list.where((d) => _sexNorm(d) == 'N.D.').length, total, Colors.grey),
        ],
      ),
    );
  }

  Widget _byAgeChart(List<Doctor> list) {
    final total = list.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Per fascia d\'età'),
          const SizedBox(height: 12),
          _barRow('<30', list.where((d) => _ageOf(d) < 30).length, total,
              Colors.cyan),
          _barRow('30–40',
              list.where((d) => _ageOf(d) >= 30 && _ageOf(d) <= 40).length,
              total, Colors.teal),
          _barRow('41–50',
              list.where((d) => _ageOf(d) >= 41 && _ageOf(d) <= 50).length,
              total, Colors.indigo),
          _barRow('>50', list.where((d) => _ageOf(d) > 50).length, total,
              Colors.brown),
        ],
      ),
    );
  }

  Widget _byCityChart(List<Doctor> list) {
    final Map<String, int> cityCount = {};
    for (final d in list) {
      if (d.cityOfWork.isNotEmpty) {
        cityCount[d.cityOfWork] = (cityCount[d.cityOfWork] ?? 0) + 1;
      }
    }
    final sorted = cityCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Top città'),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const Text('Nessun dato',
                style: TextStyle(color: Colors.grey))
          else
            ...top.map(
              (e) => _barRow(e.key, e.value, maxCount, CustomColors.verdeAbisso),
            ),
        ],
      ),
    );
  }

  Widget _byFeeChart(List<Doctor> list) {
    final total = list.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Per tariffa oraria'),
          const SizedBox(height: 12),
          _barRow('€0–30',
              list.where((d) => d.hourlyFees <= 30).length, total, Colors.green),
          _barRow('€31–60',
              list.where((d) => d.hourlyFees > 30 && d.hourlyFees <= 60).length,
              total, Colors.blue),
          _barRow('€61–100',
              list.where((d) => d.hourlyFees > 60 && d.hourlyFees <= 100).length,
              total, Colors.orange),
          _barRow('>€100',
              list.where((d) => d.hourlyFees > 100).length, total,
              CustomColors.rossoSimone),
        ],
      ),
    );
  }

  Widget _doctorTable(List<Doctor> list) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chartTitle('Elenco dottori'),
              const Spacer(),
              Text(
                '${list.length} risultati',
                style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _exportCsv(list),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Esporta CSV'),
                style: TextButton.styleFrom(foregroundColor: CustomColors.verdeAbisso),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _tableHeader(),
          const Divider(height: 1),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nessun dottore trovato',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            )
          else
            ...list.take(100).map(_tableRow),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    Widget col(String label, String sortKey, int flex,
        {bool sortable = true}) {
      final isActive = _sortBy == sortKey;
      return Expanded(
        flex: flex,
        child: sortable
            ? InkWell(
                onTap: () => _toggleSort(sortKey),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isActive
                            ? CustomColors.verdeAbisso
                            : Colors.black87,
                      ),
                    ),
                    if (isActive)
                      Icon(
                        _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: CustomColors.verdeAbisso,
                      ),
                  ],
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          col('Nome', 'name', 3),
          col('Ruolo/i', 'role', 3, sortable: false),
          col('Sesso', 'sex', 1),
          col('Età', 'age', 1),
          col('Città', 'city', 2),
          col('Tariffa', 'fee', 1),
          col('Setup', 'setup', 1, sortable: false),
          col('Iscritto il', 'date', 2),
        ],
      ),
    );
  }

  Widget _tableRow(Doctor d) {
    final dateStr = d.signupApprovalDate != null
        ? DateFormat('dd/MM/yyyy').format(d.signupApprovalDate!)
        : '—';

    Widget cell(Widget child, int flex) =>
        Expanded(flex: flex, child: child);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            cell(
              Text(
                '${d.surname} ${d.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              3,
            ),
            cell(
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: d.roles.map(_roleBadge).toList(),
              ),
              3,
            ),
            cell(
              Text(_sexNorm(d), style: const TextStyle(fontSize: 13)),
              1,
            ),
            cell(
              Text('${_ageOf(d)}', style: const TextStyle(fontSize: 13)),
              1,
            ),
            cell(
              Text(
                d.cityOfWork.isNotEmpty ? d.cityOfWork : '—',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              2,
            ),
            cell(
              Text(
                d.hourlyFees > 0 ? '€${d.hourlyFees.toStringAsFixed(0)}/h' : '—',
                style: const TextStyle(fontSize: 13),
              ),
              1,
            ),
            cell(
              Icon(
                d.hasCompletedServiceSetup
                    ? Icons.check_circle
                    : Icons.cancel,
                size: 18,
                color: d.hasCompletedServiceSetup
                    ? Colors.green
                    : Colors.grey,
              ),
              1,
            ),
            cell(
              Text(dateStr, style: const TextStyle(fontSize: 13)),
              2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case Doctor.ROLE_NUTRITIONIST:
        color = Colors.green;
        label = 'Alimentare';
        break;
      case Doctor.ROLE_PERSONAL_TRAINER:
        color = Colors.orange;
        label = 'Motoria';
        break;
      case Doctor.ROLE_PSYCHOLOGIST:
        color = Colors.purple;
        label = 'Mentale';
        break;
      default:
        color = Colors.grey;
        label = role;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
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
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case Doctor.ROLE_NUTRITIONIST:
        return 'Alimentare';
      case Doctor.ROLE_PERSONAL_TRAINER:
        return 'Motoria';
      case Doctor.ROLE_PSYCHOLOGIST:
        return 'Mentale';
      default:
        return role;
    }
  }

  // ─── Sottomenu ────────────────────────────────────────────────────────────────

  Widget _subMenu() {
    final modes = [
      (key: 'lista',   label: 'Lista',       icon: Icons.list_alt_outlined),
      (key: 'ruolo',   label: 'Per ruolo',   icon: Icons.category_outlined),
      (key: 'citta',   label: 'Per città',   icon: Icons.location_city_outlined),
      (key: 'eta',     label: 'Per età',     icon: Icons.cake_outlined),
      (key: 'tariffa', label: 'Per tariffa', icon: Icons.euro_outlined),
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
      case 'ruolo':   return _clusterByRole();
      case 'citta':   return _clusterByCity();
      case 'eta':     return _clusterByAge();
      case 'tariffa': return _clusterByFee();
      default:        return const SizedBox.shrink();
    }
  }

  // ─── Cluster by role ──────────────────────────────────────────────────────────

  Widget _clusterByRole() {
    final defs = [
      (key: Doctor.ROLE_NUTRITIONIST,     label: 'Salute Alimentare', color: const Color(0xFF4CAF50), icon: Icons.local_dining_outlined),
      (key: Doctor.ROLE_PERSONAL_TRAINER, label: 'Salute Motoria',    color: const Color(0xFFFF9800), icon: Icons.fitness_center_outlined),
      (key: Doctor.ROLE_PSYCHOLOGIST,     label: 'Salute Mentale',    color: const Color(0xFF9C27B0), icon: Icons.psychology_outlined),
    ];
    return _clusterGrid([
      for (final d in defs)
        (
          label: d.label,
          color: d.color,
          icon: d.icon,
          members: widget.doctors.where((doc) => doc.roles.contains(d.key)).toList(),
          total: widget.doctors.length,
        ),
    ]);
  }

  // ─── Cluster by city ──────────────────────────────────────────────────────────

  Widget _clusterByCity() {
    final cityMap = <String, List<Doctor>>{};
    for (final d in widget.doctors) {
      final city = d.cityOfWork.trim().isEmpty ? 'Non specificata' : d.cityOfWork.trim();
      cityMap.putIfAbsent(city, () => []).add(d);
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
          total: widget.doctors.length,
        ),
    ]);
  }

  // ─── Cluster by age ───────────────────────────────────────────────────────────

  Widget _clusterByAge() {
    final now = DateTime.now();
    int ageOf(Doctor d) {
      int age = now.year - d.birthdate.year;
      if (now.month < d.birthdate.month ||
          (now.month == d.birthdate.month && now.day < d.birthdate.day)) {
        age--;
      }
      return age;
    }

    final bands = [
      (label: 'Under 30', color: const Color(0xFF4CAF50), icon: Icons.person_outline,    minAge: 0,  maxAge: 29),
      (label: '30 – 40',  color: const Color(0xFF2196F3), icon: Icons.person,             minAge: 30, maxAge: 40),
      (label: '41 – 50',  color: const Color(0xFFFF9800), icon: Icons.person_2_outlined,  minAge: 41, maxAge: 50),
      (label: '50+',      color: const Color(0xFF9C27B0), icon: Icons.person_3_outlined,  minAge: 51, maxAge: 999),
    ];
    return _clusterGrid([
      for (final b in bands)
        (
          label: b.label,
          color: b.color,
          icon: b.icon,
          members: widget.doctors.where((d) {
            final age = ageOf(d);
            return age >= b.minAge && age <= b.maxAge;
          }).toList(),
          total: widget.doctors.length,
        ),
    ]);
  }

  // ─── Cluster by fee ───────────────────────────────────────────────────────────

  Widget _clusterByFee() {
    final bands = [
      (label: '€0 – €30',   color: Colors.green,      icon: Icons.euro_outlined, minFee: 0.0,   maxFee: 30.0),
      (label: '€31 – €60',  color: Colors.teal,       icon: Icons.euro_outlined, minFee: 31.0,  maxFee: 60.0),
      (label: '€61 – €100', color: Colors.orange,     icon: Icons.euro_outlined, minFee: 61.0,  maxFee: 100.0),
      (label: 'Oltre €100', color: Colors.deepOrange, icon: Icons.euro_outlined, minFee: 101.0, maxFee: 9999.0),
    ];
    return _clusterGrid([
      for (final b in bands)
        (
          label: b.label,
          color: b.color,
          icon: b.icon,
          members: widget.doctors
              .where((d) => d.hourlyFees >= b.minFee && d.hourlyFees <= b.maxFee)
              .toList(),
          total: widget.doctors.length,
        ),
    ]);
  }

  // ─── Cluster grid & card ──────────────────────────────────────────────────────

  Map<String, String> _clusterStats(List<Doctor> members) {
    if (members.isEmpty) return {};
    final now = DateTime.now();
    final ages = members.map((d) {
      int age = now.year - d.birthdate.year;
      if (now.month < d.birthdate.month ||
          (now.month == d.birthdate.month && now.day < d.birthdate.day)) {
        age--;
      }
      return age;
    }).toList();
    final avgAge =
        (ages.fold(0, (s, a) => s + a) / ages.length).toStringAsFixed(0);
    final avgFee =
        (members.fold(0.0, (s, d) => s + d.hourlyFees) / members.length)
            .toStringAsFixed(0);
    final setupDone =
        members.where((d) => d.hasCompletedServiceSetup).length;
    final cities = <String, int>{};
    for (final d in members) {
      final c = d.cityOfWork.trim();
      if (c.isNotEmpty) cities[c] = (cities[c] ?? 0) + 1;
    }
    final topCity = cities.isEmpty
        ? '—'
        : (cities.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return {
      'Età media': '$avgAge aa',
      'Tariffa media': '€$avgFee/h',
      'Setup ok': '$setupDone/${members.length}',
      'Città top': topCity,
    };
  }

  Widget _clusterGrid(
    List<({String label, Color color, IconData icon, List<Doctor> members, int total})>
        clusters,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: clusters
          .map((c) => SizedBox(width: 340, child: _clusterCard(c)))
          .toList(),
    );
  }

  Widget _clusterCard(
    ({String label, Color color, IconData icon, List<Doctor> members, int total}) cluster,
  ) {
    final count = cluster.members.length;
    final pct =
        cluster.total == 0 ? 0.0 : count / cluster.total;
    final stats = _clusterStats(cluster.members);
    final names = cluster.members
        .map((d) => '${d.name} ${d.surname}')
        .take(5)
        .toList();

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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cluster.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cluster.icon,
                      color: cluster.color, size: 20),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.verdeAbisso,
                        ),
                      ),
                      Text(
                        '$count professionista${count == 1 ? '' : 'i'}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cluster.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(cluster.color),
              ),
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: stats.entries
                    .map(
                      (e) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.value,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
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
            ],
            if (names.isNotEmpty) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: names
                    .map(
                      (name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CustomColors.mentaFredda,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            color: CustomColors.verdeAbisso,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (cluster.members.length > 5) ...[
                const SizedBox(height: 6),
                Text(
                  '+ altri ${cluster.members.length - 5}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
