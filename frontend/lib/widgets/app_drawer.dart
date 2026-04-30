import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;

  const AppDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xF2FFFFFF),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF5FF), Color(0xFFDCEBFF)],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ML Studio',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Build, compare, and deploy model flows',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _item(context, Icons.upload_file_rounded, 'Upload Data', 0, '/'),
                    _item(context, Icons.query_stats_rounded, 'Explore Data', 1, '/overview'),
                    _item(context, Icons.health_and_safety_rounded, 'Data Quality', 7,
                        '/data_quality'),
                    _item(context, Icons.tune_rounded, 'Train Model', 2, '/model'),
                    _item(context, Icons.auto_graph_rounded, 'Predict', 3, '/predict'),
                    _item(context, Icons.inventory_2_rounded, 'Model Registry', 4,
                        '/model_registry'),
                    _item(context, Icons.timeline_rounded, 'Experiments', 5,
                        '/experiments'),
                    _item(context, Icons.visibility_rounded, 'Explainability', 6,
                        '/explainability'),
                  ],
                ),
              ),
              const Text(
                'v2 ML Platform',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    int index,
    String route,
  ) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0x1F1F4A7C) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: isSelected ? AppColors.accent : AppColors.textMuted),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, route);
          },
        ),
      ),
    );
  }
}
