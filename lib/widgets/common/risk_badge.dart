import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class RiskBadge extends StatelessWidget {
  final String risk;
  final bool compact;

  const RiskBadge({super.key, required this.risk, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forRisk(risk);
    final label = risk.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical:   compact ? 3  : 5,
      ),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:       color,
          fontSize:    compact ? 10 : 11,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class DaysBadge extends StatelessWidget {
  final int daysUntil;
  final String risk;

  const DaysBadge({super.key, required this.daysUntil, required this.risk});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDays(risk, daysUntil);
    final label = daysUntil == 0 ? 'TODAY' : '$daysUntil DAYS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.27)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
