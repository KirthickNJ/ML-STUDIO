import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';
import 'prediction_screen.dart';

class TrainingResultScreen extends StatefulWidget {
  const TrainingResultScreen({super.key});

  @override
  State<TrainingResultScreen> createState() => _TrainingResultScreenState();
}

class _TrainingResultScreenState extends State<TrainingResultScreen> {
  double threshold = 0.5;

  String _prettyName(String raw) {
    return raw
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Map<String, dynamic>? _closestThresholdMetrics(List<dynamic> rows) {
    if (rows.isEmpty) return null;
    final parsed = rows
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    parsed.sort(
      (a, b) =>
          (((a['threshold'] as num?)?.toDouble() ?? 0.5) - threshold).abs().compareTo(
                (((b['threshold'] as num?)?.toDouble() ?? 0.5) - threshold).abs(),
              ),
    );
    return parsed.first;
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    final metrics = (args?['metrics'] as Map<String, dynamic>?) ?? {};
    final targetColumn = args?['target_column']?.toString() ?? '';
    final problemType = args?['problem_type']?.toString() ?? '-';
    final algorithm = args?['algorithm']?.toString() ?? '-';
    final recommended = args?['recommended_algorithm']?.toString() ?? '-';
    final featureColumns = ((args?['feature_columns'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final diagnostics = (args?['diagnostics'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{};

    final kind = diagnostics['kind']?.toString();
    final thresholdRows = (diagnostics['threshold_metrics'] as List?) ?? [];
    final selectedThresholdMetrics = _closestThresholdMetrics(thresholdRows);

    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 2),
      appBar: AppBar(title: const Text('Training Results')),
      body: StudioBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Reveal(
                  delayMs: 40,
                  child: Text(
                    'Model Trained Successfully',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  delayMs: 90,
                  child: SectionCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Problem: ${problemType.toUpperCase()}')),
                        Chip(label: Text('Target: ${targetColumn.isEmpty ? '-' : targetColumn}')),
                        Chip(label: Text('Selected: ${_prettyName(algorithm)}')),
                        Chip(
                          backgroundColor: const Color(0x2235D07F),
                          label: Text('Suggested: ${_prettyName(recommended)}'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  delayMs: 140,
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Evaluation Metrics',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ...metrics.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(color: AppColors.textMuted),
                                  ),
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (kind == 'classification')
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Diagnostics: Confusion Matrix',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(
                          'Classes: ${((diagnostics['classes'] as List?) ?? []).join(', ')}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        ...((diagnostics['confusion_matrix'] as List?) ?? []).map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              (row as List).join('   '),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                        if (thresholdRows.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('Threshold Tuning',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Slider(
                            value: threshold,
                            min: 0.1,
                            max: 0.9,
                            divisions: 16,
                            label: threshold.toStringAsFixed(2),
                            onChanged: (v) => setState(() => threshold = v),
                          ),
                          if (selectedThresholdMetrics != null)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                    label: Text(
                                        'Accuracy: ${selectedThresholdMetrics['accuracy']}')),
                                Chip(
                                    label: Text(
                                        'Precision: ${selectedThresholdMetrics['precision']}')),
                                Chip(
                                    label: Text(
                                        'Recall: ${selectedThresholdMetrics['recall']}')),
                                Chip(label: Text('F1: ${selectedThresholdMetrics['f1']}')),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                if (kind == 'regression')
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Diagnostics: Residual Health',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ((diagnostics['residual_summary'] as Map?)
                                      ?.entries
                                      .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                                      .toList() ??
                                  []),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Reveal(
                  delayMs: 190,
                  child: ElevatedButton.icon(
                    onPressed: featureColumns.isEmpty || targetColumn.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PredictionScreen(
                                  columns: featureColumns,
                                  target: targetColumn,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.auto_graph_rounded),
                    label: const Text('Open Prediction Workspace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
