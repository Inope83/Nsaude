import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final visual = statusVisualFromCode(code);
    if (visual == null) {
      return Text(code, style: Theme.of(context).textTheme.bodySmall);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: AppSpacing.s16, color: visual.foreground),
          const SizedBox(width: AppSpacing.s4),
          Text(
            visual.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: visual.foreground),
          ),
        ],
      ),
    );
  }
}