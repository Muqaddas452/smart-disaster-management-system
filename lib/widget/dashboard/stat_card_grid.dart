import 'package:flutter/material.dart';
import '../../model/stat_item.dart';
import '../../core/utils/responsive.dart';
import '../common/stat_card.dart';

class StatCardGrid extends StatelessWidget {
  final List<StatItem> items;

  const StatCardGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.statColumns(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) => SizedBox(width: itemWidth, child: StatCard(item: item))).toList(),
        );
      },
    );
  }
}
