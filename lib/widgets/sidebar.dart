import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A),
            ),
            child: Center(
              child: Text(
                "ML Studio",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _drawerItem(Icons.upload_file, "Upload Data", 0),
          _drawerItem(Icons.analytics, "Explore Data", 1),
          _drawerItem(Icons.memory, "Train Model", 2),
          _drawerItem(Icons.play_arrow, "Predict", 3),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    final isSelected = selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
        ),
      ),
      tileColor: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
      onTap: () => onTap(index),
    );
  }
}