import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';
import 'prediction_screen.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvePredictRoute();
  }

  Future<void> _resolvePredictRoute() async {
    try {
      await ApiService.syncModelStatus();
    } catch (_) {}

    if (!mounted) return;

    final columns = ApiService.trainedFeatureColumns;
    final target = ApiService.trainedTargetColumn;

    if (ApiService.hasDatasetLoaded && columns.isNotEmpty && target != null && target.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PredictionScreen(columns: columns, target: target),
        ),
      );
      return;
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 3),
      appBar: AppBar(title: const Text('Predict')),
      body: StudioBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const CircularProgressIndicator()
                : Reveal(
                    child: EmptyState(
                      icon: Icons.analytics_outlined,
                      title: 'No Active Model',
                      subtitle:
                          'Train a model first to enable prediction inputs and inference output.',
                      action: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/model');
                        },
                        child: const Text('Go To Train Model'),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
