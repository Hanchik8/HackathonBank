import 'package:flutter/material.dart';

class SegmentedSpendBar extends StatelessWidget {
  const SegmentedSpendBar({
    super.key,
    required this.segments,
    this.height = 16,
    this.backgroundColor = const Color(0xFF2A2C30),
  });

  final List<SpendSegment> segments;
  final double height;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.value,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: backgroundColor,
        child: Row(
          children: segments.map((segment) {
            final flex = total == 0
                ? 0
                : (segment.value / total * 1000).round();
            return Expanded(
              flex: flex == 0 ? 1 : flex,
              child: Container(color: segment.color),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class SpendSegment {
  const SpendSegment({required this.color, required this.value});

  final Color color;
  final double value;
}
