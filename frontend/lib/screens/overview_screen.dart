import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> summaryData = {};
  Map<String, dynamic> infoData = {};
  List<Map<String, dynamic>> missingChart = [];
  List<Map<String, dynamic>> numericProfiles = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchOverview() async {
    try {
      final response = await ApiService.getOverview();

      if (response.containsKey('error')) {
        setState(() {
          errorMessage = response['error'].toString();
          isLoading = false;
        });
      } else {
        setState(() {
          summaryData = (response['summary'] as Map?)
                  ?.map((k, v) => MapEntry(k.toString(), v)) ??
              {};
          infoData = (response['info'] as Map?)
                  ?.map((k, v) => MapEntry(k.toString(), v)) ??
              {};

          missingChart = ((response['charts']?['missing_values'] as List?) ?? [])
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList();

          numericProfiles =
              ((response['charts']?['numeric_profiles'] as List?) ?? [])
                  .whereType<Map>()
                  .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                  .toList();
          isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        errorMessage = 'Failed to fetch data';
        isLoading = false;
      });
    }
  }

  String _fmt(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';
    if (value is num) return value.toStringAsFixed(4);
    return value.toString();
  }

  Widget _kpiCard(String label, num value, IconData icon, {int delayMs = 0}) {
    return Expanded(
      child: Reveal(
        delayMs: delayMs,
        child: SectionCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(height: 8),
              CountUpText(
                value: value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flBarChartCard({
    required String title,
    required List<Map<String, dynamic>> data,
    required String labelKey,
    required String valueKey,
    required Color barColor,
    int maxItems = 8,
    int delayMs = 0,
  }) {
    final items = data.take(maxItems).toList();
    final maxY = items.isEmpty
        ? 1.0
        : items
                .map((e) => (e[valueKey] as num?)?.toDouble() ?? 0.0)
                .fold<double>(0.0, (a, b) => a > b ? a : b) *
            1.2;
    final bars = <BarChartGroupData>[];

    for (var i = 0; i < items.length; i++) {
      final value = (items[i][valueKey] as num?)?.toDouble() ?? 0.0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              width: 18,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [barColor.withValues(alpha: 0.65), barColor],
              ),
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY <= 0 ? 1 : maxY,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    }

    return Reveal(
      delayMs: delayMs,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No chart data available',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else ...[
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY <= 0 ? 1 : maxY,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white12,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        left: BorderSide(color: Colors.white24),
                        bottom: BorderSide(color: Colors.white24),
                        right: BorderSide.none,
                        top: BorderSide.none,
                      ),
                    ),
                    barGroups: bars,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 10,
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipColor: (_) => AppColors.panelAlt.withValues(alpha: 0.95),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final idx = group.x;
                          if (idx < 0 || idx >= items.length) return null;
                          final label = items[idx][labelKey]?.toString() ?? '-';
                          final value = rod.toY;
                          return BarTooltipItem(
                            '$label\n${value.toStringAsFixed(3)}',
                            const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '#${value.toInt() + 1}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textMuted),
                              ),
                            );
                          },
                          reservedSize: 22,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Legend', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...items.asMap().entries.map(
                (entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final label = item[labelKey]?.toString() ?? '-';
                  final value = (item[valueKey] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '#$idx  $label  ->  ${value.toStringAsFixed(2)}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    if (summaryData.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.table_view_outlined,
          title: 'No describe() data',
          subtitle: 'Upload a valid dataset to inspect summary statistics.',
        ),
      );
    }

    return ListView(
      children: summaryData.entries.toList().asMap().entries.map((entryWrap) {
        final idx = entryWrap.key;
        final entry = entryWrap.value;
        final column = entry.key;
        final stats = (entry.value as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v)) ??
            <String, dynamic>{};

        return Reveal(
          delayMs: 40 + (idx * 30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(column,
                      style:
                          const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.entries
                        .map(
                          (item) => Chip(
                            label: Text('${item.key}: ${_fmt(item.value)}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoPanel() {
    if (infoData.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.info_outline,
          title: 'No info() data',
          subtitle: 'Upload a dataset to view schema and null diagnostics.',
        ),
      );
    }

    final rows = (infoData['rows'] as num?) ?? 0;
    final cols = (infoData['columns'] as num?) ?? 0;
    final dup = (infoData['duplicate_rows'] as num?) ?? 0;
    final mem = (infoData['memory_usage_bytes'] as num?) ?? 0;

    final dtypes = (infoData['dtypes'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        <String, String>{};

    final nullCounts = (infoData['null_counts'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{};

    final nonNullCounts = (infoData['non_null_counts'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{};

    return ListView(
      children: [
        Row(
          children: [
            _kpiCard('Rows', rows, Icons.table_rows, delayMs: 40),
            const SizedBox(width: 10),
            _kpiCard('Columns', cols, Icons.view_column, delayMs: 80),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _kpiCard('Duplicate Rows', dup, Icons.copy_all, delayMs: 110),
            const SizedBox(width: 10),
            _kpiCard('Memory (bytes)', mem, Icons.memory, delayMs: 140),
          ],
        ),
        const SizedBox(height: 12),
        Reveal(
          delayMs: 180,
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Column Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...dtypes.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${e.key}: ${e.value}'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          delayMs: 220,
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Null / Non-Null Counts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...dtypes.keys.map(
                  (col) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$col  |  null: ${nullCounts[col] ?? 0}, non-null: ${nonNullCounts[col] ?? 0}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartsPanel() {
    return ListView(
      children: [
        _flBarChartCard(
          title: 'Missing % by Column (Top)',
          data: missingChart,
          labelKey: 'column',
          valueKey: 'missing_pct',
          barColor: AppColors.accent2,
          delayMs: 70,
        ),
        const SizedBox(height: 12),
        _flBarChartCard(
          title: 'Numeric Column Std Dev (Top)',
          data: numericProfiles,
          labelKey: 'column',
          valueKey: 'std',
          barColor: AppColors.accent,
          delayMs: 150,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 1),
      appBar: AppBar(
        title: const Text('Explore Data'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Info'),
            Tab(text: 'Charts'),
          ],
        ),
      ),
      body: StudioBackground(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Could not load data',
                        subtitle: errorMessage!,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSummaryTable(),
                        _buildInfoPanel(),
                        _buildChartsPanel(),
                      ],
                    ),
        ),
      ),
    );
  }
}
