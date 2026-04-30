import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class PredictionScreen extends StatefulWidget {
  final List<String> columns;
  final String target;

  const PredictionScreen({
    super.key,
    required this.columns,
    required this.target,
  });

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final Map<String, TextEditingController> controllers = {};
  String result = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    for (final col in widget.columns) {
      if (col != widget.target) {
        controllers[col] = TextEditingController();
      }
    }
  }

  Future<void> predict() async {
    setState(() {
      loading = true;
      result = '';
    });

    final inputData = <String, dynamic>{};
    controllers.forEach((key, controller) {
      inputData[key] = double.tryParse(controller.text) ?? 0;
    });

    try {
      final response = await ApiService.predict(inputData);

      setState(() {
        if (response.containsKey('prediction')) {
          result = 'Prediction: ${response['prediction']}';
        } else {
          result = 'Error: ${response['error'] ?? 'Unknown error'}';
        }
      });
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
    }

    setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Color _resultColor() {
    if (result.startsWith('Error')) return AppColors.danger;
    if (result.startsWith('Prediction')) return AppColors.success;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 3),
      appBar: AppBar(title: const Text('Prediction Workspace')),
      body: StudioBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Reveal(
                  delayMs: 30,
                  child: AnimatedGradientHeader(
                    title: 'Inference Input',
                    subtitle: 'Target column: ${widget.target}',
                  ),
                ),
                const SizedBox(height: 14),
                Reveal(
                  delayMs: 120,
                  child: SectionCard(
                    child: Column(
                      children: [
                        if (controllers.isEmpty)
                          const Text(
                            'No feature columns available for prediction.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ...controllers.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: entry.value,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: entry.key,
                                prefixIcon: const Icon(Icons.tune),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ElevatedButton.icon(
                          onPressed: loading ? null : predict,
                          icon: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_graph_rounded),
                          label: Text(loading ? 'Predicting...' : 'Run Prediction'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  delayMs: 180,
                  child: SectionCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.insights_rounded, color: _resultColor()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result.isEmpty ? 'Prediction output will appear here.' : result,
                            style:
                                TextStyle(color: _resultColor(), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
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
