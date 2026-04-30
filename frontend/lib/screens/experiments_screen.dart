import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class ExperimentsScreen extends StatefulWidget {
  const ExperimentsScreen({super.key});

  @override
  State<ExperimentsScreen> createState() => _ExperimentsScreenState();
}

class _ExperimentsScreenState extends State<ExperimentsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> experiments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.listExperiments();
      experiments = ((response['experiments'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _rerun(String experimentId) async {
    final response = await ApiService.rerunExperiment(experimentId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? 'Rerun finished')),
    );

    if (response['metrics'] != null) {
      Navigator.pushNamed(context, '/training_result', arguments: response);
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 5),
      appBar: AppBar(
        title: const Text('Experiments Timeline'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: StudioBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: 'Failed To Load Experiments',
                      subtitle: error!,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: experiments.isEmpty
                        ? const Center(
                            child: EmptyState(
                              icon: Icons.timeline_outlined,
                              title: 'No Experiment Runs',
                              subtitle: 'Train models to automatically log experiment history.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: experiments.length,
                            itemBuilder: (context, index) {
                              final exp = experiments[index];
                              final metrics = (exp['metrics'] as Map?)
                                      ?.map((k, v) => MapEntry(k.toString(), v)) ??
                                  {};
                              final cv = (metrics['cv'] as Map?)
                                      ?.map((k, v) => MapEntry(k.toString(), v)) ??
                                  {};
                              final trainParams = (exp['train_params'] as Map?)
                                      ?.map((k, v) => MapEntry(k.toString(), v)) ??
                                  {};
                              final experimentId = exp['experiment_id']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SectionCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Run ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Algorithm: ${exp['algorithm']}  |  Problem: ${exp['problem_type']}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      Text(
                                        'Target: ${exp['target_column']}  |  Objective: ${exp['objective'] ?? '-'}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      Text(
                                        'Dataset hash: ${exp['dataset_hash'] ?? '-'}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      Text(
                                        'Created: ${exp['created_at']}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (cv['score_mean'] != null)
                                            Chip(
                                                label: Text(
                                                    'CV mean: ${cv['score_mean']}')),
                                          if (cv['score_std'] != null)
                                            Chip(
                                                label: Text(
                                                    'CV std: ${cv['score_std']}')),
                                          if (trainParams['seed'] != null)
                                            Chip(
                                                label: Text(
                                                    'Seed: ${trainParams['seed']}')),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: experimentId.isEmpty
                                            ? null
                                            : () => _rerun(experimentId),
                                        icon: const Icon(Icons.replay_rounded),
                                        label: const Text('Re-run Exact Experiment'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}
