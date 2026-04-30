import 'package:flutter/material.dart';

import 'screens/data_quality_screen.dart';
import 'screens/experiments_screen.dart';
import 'screens/explainability_screen.dart';
import 'screens/model_registry_screen.dart';
import 'screens/model_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/training_result_screen.dart';
import 'screens/upload_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MLStudioApp());
}

class MLStudioApp extends StatelessWidget {
  const MLStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ML Studio',
      theme: AppTheme.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const UploadScreen(),
        '/overview': (context) => const OverviewScreen(),
        '/model': (context) => const ModelScreen(),
        '/predict': (context) => const PredictScreen(),
        '/training_result': (context) => const TrainingResultScreen(),
        '/model_registry': (context) => const ModelRegistryScreen(),
        '/experiments': (context) => const ExperimentsScreen(),
        '/explainability': (context) => const ExplainabilityScreen(),
        '/data_quality': (context) => const DataQualityScreen(),
      },
    );
  }
}
