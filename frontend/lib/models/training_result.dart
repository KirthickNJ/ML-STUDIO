class FeatureImportance {
  final String feature;
  final double importance;

  FeatureImportance({
    required this.feature,
    required this.importance,
  });

  factory FeatureImportance.fromJson(Map<String, dynamic> json) {
    return FeatureImportance(
      feature: json["feature"],
      importance: (json["importance"] as num).toDouble(),
    );
  }
}

class TrainingResult {
  final String problemType;
  final String modelUsed;
  final double score;
  final List<FeatureImportance> features;
  final List<String> columns;
  final String target;

  TrainingResult({
    required this.problemType,
    required this.modelUsed,
    required this.score,
    required this.features,
    required this.columns,
    required this.target,
  });

  factory TrainingResult.fromJson(Map<String, dynamic> json) {
    return TrainingResult(
      problemType: json["problem_type"],
      modelUsed: json["model_used"],
      score: (json["score"] as num).toDouble(),
      features: (json["features"] as List)
          .map((f) => FeatureImportance.fromJson(f))
          .toList(),
      columns: List<String>.from(json["columns"]),
      target: json["target"],
    );
  }
}