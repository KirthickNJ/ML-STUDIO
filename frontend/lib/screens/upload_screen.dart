import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ui_kit.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool isUploading = false;
  bool isLoadingSamples = true;
  int selectedMode = 0;
  String statusMessage = 'No file selected';

  String? currentDatasetName;
  String? currentDatasetHash;
  String? currentDatasetUploadedAt;
  int? currentRows;
  int? currentColumns;
  String? currentDatasetSource;
  List<Map<String, dynamic>> builtinSamples = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentDataset();
    _loadBuiltinSamples();
  }

  Future<void> _loadCurrentDataset() async {
    try {
      final status = await ApiService.syncModelStatus();
      final hasDataset = status['has_dataset_loaded'] == true;

      if (!hasDataset) {
        if (!mounted) return;
        setState(() {
          currentDatasetName = null;
          currentDatasetHash = null;
          currentDatasetUploadedAt = null;
          currentRows = null;
          currentColumns = null;
          currentDatasetSource = null;
          if (!isUploading) statusMessage = 'No file selected';
        });
        return;
      }

      final overview = await ApiService.getOverview();
      final info = (overview['info'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};

      if (!mounted) return;
      setState(() {
        currentDatasetName = info['dataset_name']?.toString() ?? status['dataset_name']?.toString();
        currentDatasetHash = info['dataset_hash']?.toString() ?? status['dataset_hash']?.toString();
        currentDatasetUploadedAt =
            info['dataset_uploaded_at']?.toString() ?? status['dataset_uploaded_at']?.toString();
        currentRows = (info['rows'] as num?)?.toInt();
        currentColumns = (info['columns'] as num?)?.toInt();
        currentDatasetSource =
            info['dataset_source']?.toString() ?? status['dataset_source']?.toString();
        if (!isUploading) {
          statusMessage = 'Current dataset loaded: ${currentDatasetName ?? 'dataset'}';
        }
      });
    } catch (_) {
      // Keep screen usable even if backend is unavailable.
    }
  }

  Future<void> _loadBuiltinSamples() async {
    try {
      final response = await ApiService.listBuiltinSamples();
      final samples = ((response['samples'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      if (!mounted) return;
      setState(() {
        builtinSamples = samples;
        isLoadingSamples = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingSamples = false);
    }
  }

  Future<void> _loadSample(String sampleKey, String title) async {
    setState(() {
      isUploading = true;
      statusMessage = 'Loading built-in dataset: $title...';
    });

    try {
      final response = await ApiService.loadBuiltinSample(sampleKey);
      if (response.containsKey('error')) {
        setState(() {
          statusMessage = 'Error: ${response['error']}';
          isUploading = false;
        });
        return;
      }

      await _loadCurrentDataset();

      if (!mounted) return;
      setState(() {
        statusMessage = 'Built-in dataset loaded: $title';
        isUploading = false;
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/overview');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Failed to load built-in dataset';
        isUploading = false;
      });
    }
  }

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls', 'json', 'parquet', 'txt'],
    );

    if (result == null) return;

    final file = File(result.files.single.path!);

    setState(() {
      isUploading = true;
      statusMessage = 'Uploading dataset...';
    });

    try {
      final response = await ApiService.uploadFile(file);

      if (response.containsKey('error')) {
        setState(() {
          statusMessage = 'Error: ${response['error']}';
          isUploading = false;
        });
      } else {
        setState(() {
          statusMessage = 'Upload complete. Rows: ${response['rows']}';
          isUploading = false;
        });

        await _loadCurrentDataset();

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/overview');
      }
    } catch (_) {
      setState(() {
        statusMessage = 'Upload failed';
        isUploading = false;
      });
    }
  }

  Color _statusColor() {
    if (statusMessage.startsWith('Error')) return AppColors.danger;
    if (statusMessage.toLowerCase().contains('complete')) return AppColors.success;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedIndex: 0),
      appBar: AppBar(title: const Text('Upload Dataset')),
      body: StudioBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Reveal(
                  delayMs: 40,
                  child: AnimatedGradientHeader(
                    title: 'Start With Your Data',
                    subtitle:
                        'Upload CSV, Excel, JSON, or Parquet data to generate exploration insights and model recommendations.',
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  delayMs: 70,
                  child: SectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedMode == 0
                                ? null
                                : () => setState(() => selectedMode = 0),
                            child: const Text('Upload'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedMode == 1
                                ? null
                                : () => setState(() => selectedMode = 1),
                            child: const Text('Choose'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (currentRows != null)
                  Reveal(
                    delayMs: 90,
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Uploaded Dataset',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentDatasetName ?? 'dataset',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (currentDatasetSource != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Source: $currentDatasetSource',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('Rows: ${currentRows ?? 0}')),
                              Chip(label: Text('Columns: ${currentColumns ?? 0}')),
                              if (currentDatasetHash != null && currentDatasetHash!.isNotEmpty)
                                Chip(label: Text('Hash: ${currentDatasetHash!.substring(0, 8)}...')),
                            ],
                          ),
                          if (currentDatasetUploadedAt != null &&
                              currentDatasetUploadedAt!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Uploaded at: $currentDatasetUploadedAt',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                if (selectedMode == 1)
                  Reveal(
                    delayMs: 110,
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Built-In Datasets',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Use these to learn the ML workflow without bringing your own file.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          if (isLoadingSamples)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = constraints.maxWidth > 700
                                    ? 220.0
                                    : constraints.maxWidth;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: builtinSamples.map((sample) {
                                    final key = sample['key']?.toString() ?? '';
                                    final title = sample['title']?.toString() ?? 'Sample';
                                    final description =
                                        sample['description']?.toString() ?? 'Built-in sample dataset';
                                    final problemType = sample['problem_type']?.toString() ?? '-';
                                    final rows = sample['rows']?.toString() ?? '-';
                                    final columns = sample['columns']?.toString() ?? '-';

                                    return SizedBox(
                                      width: cardWidth,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: isUploading || key.isEmpty
                                            ? null
                                            : () => _loadSample(key, title),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FBFF),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0x88BBD0EA)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  Chip(label: Text(problemType)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                description,
                                                style: const TextStyle(color: AppColors.textMuted),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  Chip(label: Text('Rows: $rows')),
                                                  Chip(label: Text('Cols: $columns')),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              ElevatedButton(
                                                onPressed: isUploading || key.isEmpty
                                                    ? null
                                                    : () => _loadSample(key, title),
                                                child: const Text('Load Sample'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Reveal(
                    delayMs: 150,
                    child: GestureDetector(
                      onTap: isUploading ? null : pickAndUploadFile,
                      child: SectionCard(
                        child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x5554A6C8), width: 1.2),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0x1A1F4A7C),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: isUploading
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload_rounded,
                                        color: AppColors.accent, size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isUploading ? 'Uploading...' : 'Tap To Upload Dataset',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Supported: .csv, .xlsx, .xls, .json, .parquet, .txt',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Reveal(
                  delayMs: 220,
                  child: SectionCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _statusColor()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: TextStyle(color: _statusColor(), fontWeight: FontWeight.w600),
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
