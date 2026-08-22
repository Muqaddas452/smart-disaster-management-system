import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widget/common/glass_card.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, size: 30, color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.construction_rounded, size: 16),
                  label: const Text('Module under active development'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
