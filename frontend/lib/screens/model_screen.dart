import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});

  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  bool isLoading = true;
  bool isRecommending = false;
  bool isTraining = false;
  String? errorMessage;

  List<String> columns = [];
  String? selectedTarget;

  String? problemType;
  String? recommendedAlgorithm;
  String? selectedAlgorithm;
  String selectedObjective = 'balanced';
  List<Map<String, dynamic>> algorithmResults = [];

  static const objectiveOptions = <Map<String, String>>[
    {'value': 'balanced', 'label': 'Balanced'},
    {'value': 'f1', 'label': 'F1 Focus'},
    {'value': 'precision', 'label': 'Precision Focus'},
    {'value': 'recall', 'label': 'Recall Focus'},
    {'value': 'r2', 'label': 'R2 Focus'},
    {'value': 'mae', 'label': 'Low MAE'},
    {'value': 'rmse', 'label': 'Low RMSE'},
  ];

  @override
  void initState() {
    super.initState();
    fetchColumns();
  }

  Future<void> fetchColumns() async {
    try {
      final response = await ApiService.getOverview();

      if (response.containsKey('error')) {
        setState(() {
          errorMessage = response['error'].toString();
          isLoading = false;
        });
      } else {
        setState(() {
          columns = (response['summary'] as Map<String, dynamic>)
              .keys
              .map((e) => e.toString())
              .toList();
          isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        errorMessage = 'Failed to load dataset';
        isLoading = false;
      });
    }
  }

  Future<void> _recommendAlgorithms() async {
    if (selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target column')),
      );
      return;
    }

    setState(() {
      isRecommending = true;
      errorMessage = null;
      problemType = null;
      recommendedAlgorithm = null;
      selectedAlgorithm = null;
      algorithmResults = [];
    });

    try {
      final data = await ApiService.recommendAlgorithms(
        selectedTarget!,
        objective: selectedObjective,
      );

      if (!mounted) return;

      if (data['algorithms'] is List) {
        final parsedResults = (data['algorithms'] as List)
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList();

        setState(() {
          algorithmResults = parsedResults;
          problemType = data['problem_type']?.toString();
          recommendedAlgorithm = data['recommended_algorithm']?.toString();
          selectedAlgorithm = recommendedAlgorithm;
        });
      } else {
        setState(() {
          errorMessage = data['error']?.toString() ?? 'Failed to recommend';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to recommend algorithms';
      });
    }

    if (!mounted) return;
    setState(() => isRecommending = false);
  }

  Future<void> _trainModel() async {
    if (selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target column')),
      );
      return;
    }

    if (selectedAlgorithm == null || selectedAlgorithm!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run recommendation and choose an algorithm')),
      );
      return;
    }

    setState(() {
      isTraining = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.trainModel(
        selectedTarget!,
        algorithm: selectedAlgorithm,
        objective: selectedObjective,
      );

      if (!mounted) return;

      if (data['metrics'] != null) {
        Navigator.pushNamed(context, '/training_result', arguments: data);
      } else {
        setState(() {
          errorMessage = data['error']?.toString() ?? 'Training failed';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMessage = 'Training failed');
    }

    if (!mounted) return;
    setState(() => isTraining = false);
  }

  String _prettyAlgorithmName(String raw) {
    return raw
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _objectiveDisplay() {
    return objectiveOptions
            .firstWhere(
              (o) => o['value'] == selectedObjective,
              orElse: () => {'label': selectedObjective},
            )['label'] ??
        selectedObjective;
  }

  Widget _buildAlgorithmAuditPanel() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Algorithm Audit Panel',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Ranking objective: ${_objectiveDisplay()}. Top pick is chosen by highest ranking score with CV stability as secondary signal.',
            style: const TextStyle(color: Color(0xFF5F6B80)),
          ),
          const SizedBox(height: 10),
          ...algorithmResults.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final result = entry.value;
            final algo = result['algorithm']?.toString() ?? '-';
            final isWinner = algo == recommendedAlgorithm;
            final rankingScore = (result['ranking_score'] as num?)?.toDouble();
            final cv = (result['cv_metrics'] as Map?)
                    ?.map((k, v) => MapEntry(k.toString(), v)) ??
                <String, dynamic>{};
            final cvMean = (cv['score_mean'] as num?)?.toDouble();
            final cvStd = (cv['score_std'] as num?)?.toDouble();
            final stability =
                (cvMean != null && cvStd != null) ? (cvMean - cvStd).toDouble() : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWinner ? const Color(0x5535D07F) : const Color(0x55AFC1DA),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#$rank ${_prettyAlgorithmName(algo)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                            ),
                            if (isWinner)
                              const Chip(
                                backgroundColor: Color(0x2235D07F),
                                label: Text('Best'),
                              ),
                          ],
                        ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                            label: Text(
                                'Rank score: ${rankingScore?.toStringAsFixed(4) ?? '-'}')),
                        Chip(
                            label: Text(
                                'CV mean: ${cvMean?.toStringAsFixed(4) ?? '-'}')),
                        Chip(
                            label: Text(
                                'CV std: ${cvStd?.toStringAsFixed(4) ?? '-'}')),
                        Chip(
                            label: Text(
                                'Stability: ${stability?.toStringAsFixed(4) ?? '-'}')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isWinner
                          ? 'Why selected: Highest objective score in this recommendation run.'
                          : 'Not selected: Lower objective score than current winner.',
                      style: const TextStyle(color: Color(0xFF5F6B80), fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 2),
      appBar: AppBar(title: const Text('Train Model')),
      body: StudioBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: EmptyState(
                          icon: Icons.error_outline,
                          title: 'Something Went Wrong',
                          subtitle: errorMessage!,
                        ),
                      )
                    : ListView(
                        children: [
                          const Reveal(
                            delayMs: 30,
                            child: AnimatedGradientHeader(
                              title: 'Model Strategy Studio',
                              subtitle:
                                  'Pick target, set objective, compare metrics, and train a reproducible model.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Reveal(
                            delayMs: 120,
                            child: SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target Column',
                                      style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedTarget,
                                    items: columns
                                        .map(
                                          (col) => DropdownMenuItem<String>(
                                            value: col,
                                            child: Text(col),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTarget = value;
                                        problemType = null;
                                        recommendedAlgorithm = null;
                                        selectedAlgorithm = null;
                                        algorithmResults = [];
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Choose the prediction target',
                                      prefixIcon: Icon(Icons.flag_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedObjective,
                                    items: objectiveOptions
                                        .map(
                                          (item) => DropdownMenuItem<String>(
                                            value: item['value'],
                                            child: Text(item['label']!),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => selectedObjective = value);
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Choose model selection objective',
                                      prefixIcon: Icon(Icons.track_changes_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed:
                                        isRecommending ? null : _recommendAlgorithms,
                                    icon: isRecommending
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.auto_awesome_rounded),
                                    label: Text(isRecommending
                                        ? 'Analyzing...'
                                        : 'Suggest Best Algorithms'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (problemType != null) ...[
                            const SizedBox(height: 12),
                            Reveal(
                              delayMs: 180,
                              child: SectionCard(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text('Problem: ${problemType!.toUpperCase()}'),
                                    ),
                                    Chip(label: Text('Objective: $selectedObjective')),
                                    if (recommendedAlgorithm != null)
                                      Chip(
                                        backgroundColor: const Color(0x2235D07F),
                                        label: Text(
                                          'Recommended: ${_prettyAlgorithmName(recommendedAlgorithm!)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (algorithmResults.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Reveal(
                              delayMs: 220,
                              child: SectionCard(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedAlgorithm,
                                  items: algorithmResults
                                      .map(
                                        (result) => DropdownMenuItem<String>(
                                          value: result['algorithm']?.toString(),
                                          child: Text(_prettyAlgorithmName(
                                            result['algorithm'].toString(),
                                          )),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => selectedAlgorithm = value);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Final Algorithm Choice',
                                    prefixIcon: Icon(Icons.psychology_alt_outlined),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Reveal(delayMs: 320, child: _buildAlgorithmAuditPanel()),
                            const SizedBox(height: 8),
                            Reveal(
                              delayMs: 340,
                              child: ElevatedButton.icon(
                                onPressed: isTraining ? null : _trainModel,
                                icon: isTraining
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.rocket_launch_outlined),
                                label: Text(isTraining
                                    ? 'Training Model...'
                                    : 'Train Selected Algorithm'),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
