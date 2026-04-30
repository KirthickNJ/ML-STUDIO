import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class ModelRegistryScreen extends StatefulWidget {
  const ModelRegistryScreen({super.key});

  @override
  State<ModelRegistryScreen> createState() => _ModelRegistryScreenState();
}

class _ModelRegistryScreenState extends State<ModelRegistryScreen> {
  bool loading = true;
  String? error;
  String? activeModelId;
  List<Map<String, dynamic>> models = [];

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
      final response = await ApiService.listModels();
      setState(() {
        activeModelId = response['active_model_id']?.toString();
        models = ((response['models'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      });
    } catch (e) {
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _activate(String modelId) async {
    final res = await ApiService.activateModel(modelId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Model activated')),
    );
    await _load();
  }

  Future<void> _delete(String modelId) async {
    final res = await ApiService.deleteModel(modelId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Model deleted')),
    );
    await _load();
  }

  Future<void> _promote(String modelId, String stage) async {
    final res = await ApiService.updateModelStage(
      modelId,
      stage,
      approvedBy: 'ml_studio_user',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Stage updated')),
    );
    await _load();
  }

  Future<void> _rollback(String modelId) async {
    final res = await ApiService.rollbackModel(modelId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Rollback complete')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 4),
      appBar: AppBar(
        title: const Text('Model Registry'),
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
                      title: 'Failed To Load Registry',
                      subtitle: error!,
                      action: ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: models.isEmpty
                        ? const Center(
                            child: EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No Saved Models',
                              subtitle: 'Train at least one model to populate the registry.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: models.length,
                            itemBuilder: (context, index) {
                              final model = models[index];
                              final modelId = model['model_id']?.toString() ?? '';
                              final isActive = modelId == activeModelId;
                              final stage = model['stage']?.toString() ?? 'development';
                              final metrics = (model['metrics'] as Map?)
                                      ?.map((k, v) => MapEntry(k.toString(), v)) ??
                                  {};

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SectionCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              model['name']?.toString() ?? 'Unnamed model',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (isActive)
                                            const Chip(
                                              backgroundColor: Color(0x2235D07F),
                                              label: Text('Active'),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('ID: $modelId',
                                          style: const TextStyle(
                                              color: AppColors.textMuted, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Algorithm: ${model['algorithm']}  |  Problem: ${model['problem_type']}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Target: ${model['target_column']}  |  Stage: $stage',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Dataset hash: ${model['dataset_hash'] ?? '-'}',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      if (metrics.isNotEmpty)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: metrics.entries
                                              .map((e) => Chip(label: Text(e.key)))
                                              .toList(),
                                        ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: isActive || modelId.isEmpty
                                                  ? null
                                                  : () => _activate(modelId),
                                              child: const Text('Activate'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: modelId.isEmpty
                                                  ? null
                                                  : () => _rollback(modelId),
                                              child: const Text('Rollback'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: modelId.isEmpty
                                                  ? null
                                                  : () => _promote(modelId, 'staging'),
                                              child: const Text('Promote to Staging'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: modelId.isEmpty
                                                  ? null
                                                  : () => _promote(modelId, 'production'),
                                              child: const Text('Promote to Production'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: modelId.isEmpty ? null : () => _delete(modelId),
                                        child: const Text('Delete Model'),
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
