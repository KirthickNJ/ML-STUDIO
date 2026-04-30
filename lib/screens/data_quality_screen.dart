import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class DataQualityScreen extends StatefulWidget {
  const DataQualityScreen({super.key});

  @override
  State<DataQualityScreen> createState() => _DataQualityScreenState();
}

class _DataQualityScreenState extends State<DataQualityScreen> {
  bool loading = true;
  String? error;

  List<String> columns = [];
  String? selectedTarget;
  Map<String, dynamic> quality = {};
  Map<String, dynamic> monitor = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final overview = await ApiService.getOverview();
      columns = ((overview['columns'] as List?) ?? []).map((e) => e.toString()).toList();
      await _loadQuality();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadQuality() async {
    try {
      final response = await ApiService.getQuality(targetColumn: selectedTarget);
      final monitorResponse = await ApiService.getMonitor();
      quality = response;
      monitor = monitorResponse;
      error = response['error']?.toString() ?? monitorResponse['error']?.toString();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Widget _listSection(String title, List<dynamic> items) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No issues found.', style: TextStyle(color: AppColors.textMuted))
          else
            ...items.take(25).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(e.toString(), style: const TextStyle(color: AppColors.textMuted)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missingness = ((quality['missingness'] as List?) ?? []);
    final leakage = ((quality['leakage_warnings'] as List?) ?? []);
    final constants = ((quality['constant_columns'] as List?) ?? []);
    final highCardinality = ((quality['high_cardinality_columns'] as List?) ?? []);
    final imbalance = (quality['imbalance_alert'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        {};
    final drift = (monitor['drift'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    final driftAlerts = ((drift['numeric_mean_shift_alerts'] as List?) ?? []);
    final stageCounts = (monitor['registry_by_stage'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        {};

    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 7),
      appBar: AppBar(
        title: const Text('Data Quality Dashboard'),
        actions: [
          IconButton(onPressed: _loadQuality, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: StudioBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could Not Load Quality Report',
                      subtitle: error!,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        const AnimatedGradientHeader(
                          title: 'Data Quality Dashboard',
                          subtitle:
                              'Inspect leakage, imbalance, drift and data reliability before production.',
                        ),
                        const SizedBox(height: 10),
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Context',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: selectedTarget,
                                items: [
                                  const DropdownMenuItem<String>(
                                      value: null, child: Text('No target (generic checks)')),
                                  ...columns.map(
                                    (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => selectedTarget = value);
                                  _loadQuality();
                                },
                                decoration: const InputDecoration(labelText: 'Target column'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Quality Score',
                                        style: TextStyle(color: AppColors.textMuted)),
                                    CountUpText(
                                      value: (quality['quality_score'] as num?) ?? 0,
                                      suffix: '/100',
                                      fractionDigits: 1,
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Duplicates',
                                        style: TextStyle(color: AppColors.textMuted)),
                                    CountUpText(
                                      value: (quality['duplicate_rows'] as num?) ?? 0,
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SectionCard(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('Dev: ${stageCounts['development'] ?? 0}')),
                              Chip(label: Text('Staging: ${stageCounts['staging'] ?? 0}')),
                              Chip(label: Text('Prod: ${stageCounts['production'] ?? 0}')),
                            ],
                          ),
                        ),
                        if (imbalance.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SectionCard(
                            child: Text(
                              imbalance['message'] ?? 'Class imbalance detected',
                              style: const TextStyle(color: AppColors.accent2),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _listSection('Leakage Warnings', leakage),
                        const SizedBox(height: 10),
                        _listSection('Constant Columns', constants),
                        const SizedBox(height: 10),
                        _listSection('High Cardinality Columns', highCardinality),
                        const SizedBox(height: 10),
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Drift Alerts',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              if (driftAlerts.isEmpty)
                                const Text('No major drift detected.')
                              else
                                ...driftAlerts.take(20).map(
                                  (d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${d['column']}: shift z=${d['z_shift']}',
                                      style: const TextStyle(color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Top Missingness',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              if (missingness.isEmpty)
                                const Text('No missingness report available.')
                              else
                                ...missingness.take(20).map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${m['column']}: ${m['missing']} (${m['missing_pct']}%)',
                                      style: const TextStyle(color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
