import 'package:flutter/material.dart';

class ServiceShortcutTile extends StatelessWidget {
  const ServiceShortcutTile({
    super.key,
    required this.icon,
    required this.colors,
  });

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 34),
      ),
    );
  }
}
