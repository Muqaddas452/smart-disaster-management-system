import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/constants/app_colors.dart';
import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';

import '../common/glass_card.dart';
import '../common/section_header.dart';

class RiskPredictionPanel extends StatelessWidget {
  RiskPredictionPanel({super.key});

  final AffectedZoneService _zoneService = AffectedZoneService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AffectedZone>>(
      stream: _zoneService.getAffectedZones(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 430,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 430,
              child: Center(
                child: Text(
                  "Error loading prediction data",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final zones = snapshot.data ?? [];

        int low = 0;
        int medium = 0;
        int high = 0;
        int critical = 0;

        for (final zone in zones) {
          switch (zone.riskLevel.toLowerCase()) {
            case "low":
              low++;
              break;

            case "medium":
              medium++;
              break;

            case "high":
              high++;
              break;

            case "critical":
              critical++;
              break;
          }
        }

        final total = zones.isEmpty ? 1 : zones.length;

        final score = (
            critical * 100 +
                high * 66 +
                medium * 33 +
                low * 10) /
            total;

        return GlassCard(
          hoverable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.psychology_rounded,
                title: "AI Risk Prediction",
                subtitle: "Live risk index score",
              ),

              const SizedBox(height: 20),

              Center(
                child: SizedBox(
                  width: 160,
                  height: 100,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      score: score.clamp(0, 100) / 100,
                    ),
                  ),
                ),
              ),

              Center(
                child: Text(
                  score.round().toString(),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _scoreColor(score),
                  ),
                ),
              ),

              Center(
                child: Text(
                  "Risk Index",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 20),

              _riskRow(
                "Low",
                low,
                total,
                AppColors.riskLow,
              ),

              _riskRow(
                "Medium",
                medium,
                total,
                AppColors.riskMedium,
              ),

              _riskRow(
                "High",
                high,
                total,
                AppColors.riskHigh,
              ),

              _riskRow(
                "Critical",
                critical,
                total,
                AppColors.riskCritical,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _riskRow(
      String label,
      int count,
      int total,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              const SizedBox(width: 8),

              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                "$count zones",
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score < 30) return AppColors.riskLow;
    if (score < 55) return AppColors.riskMedium;
    if (score < 75) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }
}class _GaugePainter extends CustomPainter {
  final double score;

  _GaugePainter({
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height;

    final double radius = size.width / 2 - 10;

    const double strokeWidth = 14;

    final Rect rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: radius,
    );

    final Paint backgroundPaint = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      backgroundPaint,
    );

    final double sweepAngle = math.pi * score;

    final Shader shader = SweepGradient(
      startAngle: math.pi,
      endAngle: math.pi * 2,
      colors: const [
        AppColors.riskLow,
        AppColors.riskMedium,
        AppColors.riskHigh,
        AppColors.riskCritical,
      ],
    ).createShader(rect);

    final Paint valuePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      math.pi,
      sweepAngle,
      false,
      valuePaint,
    );

    final double angle = math.pi + sweepAngle;

    final double needleLength = radius - 10;

    final Offset center = Offset(cx, cy);

    final Offset needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    final Paint needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      needleEnd,
      needlePaint,
    );

    canvas.drawCircle(
      center,
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}