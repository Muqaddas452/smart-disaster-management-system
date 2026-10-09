import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../model/stat_item.dart';

class StatCard extends StatelessWidget {
  final StatItem item;

  const StatCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: item.color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              _TrendChip(label: item.trendLabel, trend: item.trend),
            ],
          ),
          const SizedBox(height: 16),
          Text(item.value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(item.title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final TrendDirection trend;

  const _TrendChip({required this.label, required this.trend});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (trend) {
      case TrendDirection.up:
        color = AppColors.success; icon = Icons.arrow_upward_rounded;
        break;
      case TrendDirection.down:
        color = AppColors.danger; icon = Icons.arrow_downward_rounded;
        break;
      case TrendDirection.flat:
        color = AppColors.warning; icon = Icons.remove_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
