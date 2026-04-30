import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000';
  static final List<Map<String, dynamic>> _history = [];

  static List<String> _trainedFeatureColumns = [];
  static String? _trainedTargetColumn;
  static String? _trainedAlgorithm;
  static String? _trainedProblemType;
  static bool _hasDatasetLoaded = false;

  static List<String> get trainedFeatureColumns =>
      List<String>.unmodifiable(_trainedFeatureColumns);
  static String? get trainedTargetColumn => _trainedTargetColumn;
  static String? get trainedAlgorithm => _trainedAlgorithm;
  static String? get trainedProblemType => _trainedProblemType;
  static bool get hasDatasetLoaded => _hasDatasetLoaded;

  static Future<Map<String, dynamic>> uploadFile(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final parsed = jsonDecode(responseData) as Map<String, dynamic>;

    _trainedFeatureColumns = [];
    _trainedTargetColumn = null;
    _trainedAlgorithm = null;
    _trainedProblemType = null;
    _hasDatasetLoaded = parsed.containsKey('rows') && !parsed.containsKey('error');
    _history.clear();

    return parsed;
  }

  static Future<Map<String, dynamic>> getOverview() async {
    final response = await http.get(Uri.parse('$baseUrl/overview'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getQuality({String? targetColumn}) async {
    final uri = targetColumn == null || targetColumn.isEmpty
        ? Uri.parse('$baseUrl/quality')
        : Uri.parse('$baseUrl/quality?target_column=$targetColumn');
    final response = await http.get(uri);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMonitor() async {
    final response = await http.get(Uri.parse('$baseUrl/monitor'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> listBuiltinSamples() async {
    final response = await http.get(Uri.parse('$baseUrl/samples'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> loadBuiltinSample(String sampleKey) async {
    final response = await http.post(
      Uri.parse('$baseUrl/samples/load'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sample_key': sampleKey}),
    );
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['dataset_name'] != null) {
      _hasDatasetLoaded = true;
    }
    _history.clear();
    return parsed;
  }

  static Future<Map<String, dynamic>> syncModelStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/model/status'));
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;

    _hasDatasetLoaded = parsed['has_dataset_loaded'] == true;

    final trained = parsed['is_trained'] == true;
    if (trained && _hasDatasetLoaded) {
      _trainedFeatureColumns = ((parsed['feature_columns'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      _trainedTargetColumn = parsed['target_column']?.toString();
      _trainedAlgorithm = parsed['algorithm']?.toString();
      _trainedProblemType = parsed['problem_type']?.toString();
    } else {
      _trainedFeatureColumns = [];
      _trainedTargetColumn = null;
      _trainedAlgorithm = null;
      _trainedProblemType = null;
    }

    return parsed;
  }

  static Future<Map<String, dynamic>> listModels() async {
    final response = await http.get(Uri.parse('$baseUrl/models'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> activateModel(String modelId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/models/activate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model_id': modelId}),
    );
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    await syncModelStatus();
    return parsed;
  }

  static Future<Map<String, dynamic>> deleteModel(String modelId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/models/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model_id': modelId}),
    );
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    await syncModelStatus();
    return parsed;
  }

  static Future<Map<String, dynamic>> updateModelStage(
    String modelId,
    String stage, {
    String? approvedBy,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/models/stage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'model_id': modelId,
          'stage': stage,
          if (approvedBy != null && approvedBy.isNotEmpty) 'approved_by': approvedBy,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      ),
    );
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    await syncModelStatus();
    return parsed;
  }

  static Future<Map<String, dynamic>> rollbackModel(String modelId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/models/rollback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model_id': modelId}),
    );
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    await syncModelStatus();
    return parsed;
  }

  static Future<Map<String, dynamic>> recommendAlgorithms(
    String targetColumn, {
    String objective = 'balanced',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target_column': targetColumn, 'objective': objective}),
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> trainModel(
    String targetColumn, {
    String? algorithm,
    String objective = 'balanced',
    int seed = 42,
    String? modelName,
  }) async {
    final payload = <String, dynamic>{
      'target_column': targetColumn,
      'objective': objective,
      'seed': seed,
    };
    if (algorithm != null && algorithm.isNotEmpty) {
      payload['algorithm'] = algorithm;
    }
    if (modelName != null && modelName.isNotEmpty) {
      payload['model_name'] = modelName;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/train'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;

    if (parsed['feature_columns'] is List && parsed['target_column'] != null) {
      _trainedFeatureColumns = (parsed['feature_columns'] as List)
          .map((e) => e.toString())
          .toList();
      _trainedTargetColumn = parsed['target_column'].toString();
      _trainedAlgorithm = parsed['algorithm']?.toString();
      _trainedProblemType = parsed['problem_type']?.toString();
      _hasDatasetLoaded = true;
    }

    return parsed;
  }

  static Future<Map<String, dynamic>> getDiagnostics({
    String? modelId,
    double? threshold,
  }) async {
    final qp = <String, String>{};
    if (modelId != null && modelId.isNotEmpty) qp['model_id'] = modelId;
    if (threshold != null) qp['threshold'] = threshold.toString();

    final uri = Uri.parse('$baseUrl/diagnostics').replace(queryParameters: qp);
    final response = await http.get(uri);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> explainModel({
    String? modelId,
    Map<String, dynamic>? input,
  }) async {
    final payload = <String, dynamic>{};
    if (modelId != null && modelId.isNotEmpty) payload['model_id'] = modelId;
    if (input != null && input.isNotEmpty) payload['input'] = input;

    final response = await http.post(
      Uri.parse('$baseUrl/explain'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> explainCompare({
    required String modelAId,
    required String modelBId,
    Map<String, dynamic>? input,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/explain/compare'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'model_a_id': modelAId,
          'model_b_id': modelBId,
          if (input != null && input.isNotEmpty) 'input': input,
        },
      ),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> explainWhatIf({
    String? modelId,
    required Map<String, dynamic> baseInput,
    required Map<String, dynamic> changes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/explain/whatif'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          if (modelId != null && modelId.isNotEmpty) 'model_id': modelId,
          'base_input': baseInput,
          'changes': changes,
        },
      ),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> listExperiments() async {
    final response = await http.get(Uri.parse('$baseUrl/experiments'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rerunExperiment(String experimentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/experiments/rerun'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'experiment_id': experimentId}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> predict(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;

    if (parsed.containsKey('prediction')) {
      _history.insert(0, {
        'timestamp': DateTime.now().toIso8601String(),
        'input': data,
        'prediction': parsed['prediction'],
      });
    }

    return parsed;
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    return List<Map<String, dynamic>>.unmodifiable(_history);
  }
}
