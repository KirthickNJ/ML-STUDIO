import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class ExplainabilityScreen extends StatefulWidget {
  const ExplainabilityScreen({super.key});

  @override
  State<ExplainabilityScreen> createState() => _ExplainabilityScreenState();
}

class _ExplainabilityScreenState extends State<ExplainabilityScreen> {
  bool loadingModels = true;
  bool loadingExplain = false;
  bool loadingCompare = false;
  bool loadingWhatIf = false;
  bool hasDatasetLoaded = false;
  String? error;

  List<Map<String, dynamic>> models = [];
  String? selectedModelId;
  String? compareModelId;

  final TextEditingController inputController =
      TextEditingController(text: '{\n  \n}');
  final TextEditingController whatIfController =
      TextEditingController(text: '{\n  \n}');

  List<Map<String, dynamic>> globalImportance = [];
  List<Map<String, dynamic>> localContributions = [];
  List<String> topFeatureOverlap = [];
  Map<String, dynamic> whatIfResult = {};
  String note = '';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    inputController.dispose();
    whatIfController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedModel {
    for (final m in models) {
      if (m['model_id']?.toString() == selectedModelId) return m;
    }
    return null;
  }

  Future<void> _loadModels() async {
    setState(() {
      loadingModels = true;
      error = null;
    });

    try {
      final hadSessionDataset = ApiService.hasDatasetLoaded;
      final status = await ApiService.syncModelStatus();
      final backendDatasetLoaded = status['has_dataset_loaded'] == true;
      hasDatasetLoaded = hadSessionDataset && backendDatasetLoaded;

      if (!hasDatasetLoaded) {
        models = [];
        selectedModelId = null;
        compareModelId = null;
      } else {
        final response = await ApiService.listModels();
        final active = response['active_model_id']?.toString();

        models = ((response['models'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        selectedModelId =
            active ?? (models.isNotEmpty ? models.first['model_id']?.toString() : null);
        compareModelId = models.length > 1
            ? models.firstWhere(
                (m) => m['model_id']?.toString() != selectedModelId,
                orElse: () => <String, dynamic>{},
              )['model_id']
            : null;
      }
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    setState(() => loadingModels = false);
  }

  void _fillJsonTemplate() {
    if (!hasDatasetLoaded) {
      setState(() {
        error = 'Upload a dataset in this app session before generating a template.';
      });
      return;
    }

    final model = _selectedModel;
    if (model == null) return;

    final features = ((model['feature_columns'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final schema = (model['feature_schema'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        <String, String>{};

    final template = <String, dynamic>{};
    for (final f in features) {
      if (schema[f] == 'numeric') {
        template[f] = 0;
      } else {
        template[f] = 'sample';
      }
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(template);
    inputController.text = pretty;
    whatIfController.text = pretty;
  }

  Map<String, dynamic>? _parseOptionalInput() {
    final raw = inputController.text.trim();
    if (raw.isEmpty || raw == '{}' || raw == '{\n\n}' || raw == '{\n  \n}') {
      return null;
    }

    final parsed = jsonDecode(raw);
    if (parsed is Map<String, dynamic>) {
      return parsed;
    }
    throw const FormatException('Input must be a JSON object');
  }

  Future<void> _runExplain() async {
    if (!hasDatasetLoaded) {
      setState(() {
        error = 'Upload a dataset first to use explainability.';
      });
      return;
    }

    setState(() {
      loadingExplain = true;
      error = null;
      note = '';
      globalImportance = [];
      localContributions = [];
    });

    try {
      final input = _parseOptionalInput();

      final response = await ApiService.explainModel(
        modelId: selectedModelId,
        input: input,
      );

      if (response.containsKey('error')) {
        setState(() => error = response['error'].toString());
      } else {
        globalImportance = ((response['global_feature_importance'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        localContributions = ((response['local_contributions'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        note = response['note']?.toString() ?? '';
      }
    } catch (e) {
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loadingExplain = false);
  }

  Future<void> _runCompare() async {
    if (selectedModelId == null || compareModelId == null) return;
    setState(() {
      loadingCompare = true;
      error = null;
      topFeatureOverlap = [];
    });

    try {
      final input = _parseOptionalInput();
      final response = await ApiService.explainCompare(
        modelAId: selectedModelId!,
        modelBId: compareModelId!,
        input: input,
      );

      if (response.containsKey('error')) {
        setState(() => error = response['error'].toString());
      } else {
        topFeatureOverlap = ((response['top_feature_overlap'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
      }
    } catch (e) {
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loadingCompare = false);
  }

  Future<void> _runWhatIf() async {
    setState(() {
      loadingWhatIf = true;
      error = null;
      whatIfResult = {};
    });

    try {
      final baseInput = _parseOptionalInput() ?? <String, dynamic>{};
      final changesRaw = whatIfController.text.trim();
      final parsed = jsonDecode(changesRaw);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('What-if changes must be a JSON object');
      }

      final response = await ApiService.explainWhatIf(
        modelId: selectedModelId,
        baseInput: baseInput,
        changes: parsed,
      );
      if (response.containsKey('error')) {
        setState(() => error = response['error'].toString());
      } else {
        whatIfResult = response;
      }
    } catch (e) {
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loadingWhatIf = false);
  }

  Widget _importanceList(
    String title,
    List<Map<String, dynamic>> items,
    String key,
  ) {
    final values = items
        .map((e) => ((e[key] as num?)?.toDouble() ?? 0).abs())
        .toList();
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1e-9, double.infinity);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No data yet. Run explainability to populate this section.')
          else
            ...items.take(15).map((item) {
              final feature = item['feature']?.toString() ?? '-';
              final value = ((item[key] as num?)?.toDouble() ?? 0.0);
              final pct = (value.abs() / maxValue).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feature,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(value.toStringAsFixed(4),
                            style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: pct,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          key == 'contribution' ? AppColors.accent2 : AppColors.accent,
                        ),
                        backgroundColor: const Color(0xFFDCE8F7),
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

  @override
  Widget build(BuildContext context) {
    final selected = _selectedModel;

    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 6),
      appBar: AppBar(
        title: const Text('Explainability'),
        actions: [
          IconButton(
              onPressed: loadingModels ? null : _loadModels,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: StudioBackground(
        child: loadingModels
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const AnimatedGradientHeader(
                      title: 'Explainability Workbench',
                      subtitle:
                          'Understand model behavior globally, compare candidates, and run what-if analysis.',
                    ),
                    const SizedBox(height: 10),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasDatasetLoaded) ...[
                            const Text(
                              'Upload a dataset in this app session first. Explainability unlocks only after dataset context is loaded.',
                              style: TextStyle(color: AppColors.accent2),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Text('Step 1: Choose Model',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedModelId,
                            items: models
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m['model_id']?.toString(),
                                    child: Text(
                                      '${m['name']} (${m['algorithm']})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: !hasDatasetLoaded
                                ? null
                                : (value) => setState(() => selectedModelId = value),
                            decoration: const InputDecoration(labelText: 'Primary model'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: compareModelId,
                            items: models
                                .where((m) =>
                                    m['model_id']?.toString() != selectedModelId)
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m['model_id']?.toString(),
                                    child: Text(
                                      '${m['name']} (${m['algorithm']})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: !hasDatasetLoaded
                                ? null
                                : (value) => setState(() => compareModelId = value),
                            decoration: const InputDecoration(labelText: 'Comparison model'),
                          ),
                          if (selected != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${selected['target_column']} | Features: ${((selected['feature_columns'] as List?) ?? []).length}',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Step 2: Optional Input for Local Explanation',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Provide base input for local contributions and what-if simulation.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (!hasDatasetLoaded || selected == null)
                                      ? null
                                      : _fillJsonTemplate,
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Generate Template'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: inputController,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Base Input JSON',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: loadingExplain ||
                                          selectedModelId == null ||
                                          !hasDatasetLoaded
                                      ? null
                                      : _runExplain,
                                  icon: loadingExplain
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.insights_rounded),
                              label: Text(
                                      loadingExplain ? 'Generating...' : 'Generate Insights'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: loadingCompare ||
                                          selectedModelId == null ||
                                          compareModelId == null
                                      ? null
                                      : _runCompare,
                                  icon: loadingCompare
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.compare_arrows_rounded),
                                  label: const Text('Compare Models'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Step 3: Generate Insights',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: whatIfController,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Changes JSON (fields to modify)',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: loadingWhatIf || selectedModelId == null
                                ? null
                                : _runWhatIf,
                            icon: loadingWhatIf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.tune_rounded),
                            label: Text(loadingWhatIf ? 'Simulating...' : 'Run What-If'),
                          ),
                          if (whatIfResult.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                    label: Text(
                                        'Baseline: ${whatIfResult['baseline_prediction']}')),
                                Chip(
                                    label: Text(
                                        'Changed: ${whatIfResult['changed_prediction']}')),
                                if (whatIfResult['prediction_delta'] != null)
                                  Chip(
                                      label: Text(
                                          'Delta: ${whatIfResult['prediction_delta']}')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      SectionCard(
                        child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ],
                    if (topFeatureOverlap.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SectionCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topFeatureOverlap
                              .map((e) => Chip(label: Text('Shared: $e')))
                              .toList(),
                        ),
                      ),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SectionCard(
                        child: Text(note,
                            style: const TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _importanceList('Global Feature Importance', globalImportance, 'importance'),
                    const SizedBox(height: 10),
                    _importanceList('Local Contributions', localContributions, 'contribution'),
                  ],
                ),
              ),
      ),
    );
  }
}
