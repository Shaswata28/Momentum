import 'package:flutter/material.dart';
import '../services/focus_blocker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Android requires the owner to confirm restricted settings in App info.
class RestrictedSettingsHelp extends StatelessWidget {
  const RestrictedSettingsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seeing "Restricted setting"? Open App info, tap the three-dot menu, '
          'then "Allow restricted settings" if available. Return to Accessibility '
          'and enable Momentum. Android requires you to confirm this yourself. '
          'You can keep using Momentum without Focus Shield.',
          style: AppTypography.bodyText.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        TextButton.icon(
          onPressed: () => FocusBlockerService().openAppSettings(),
          icon: const Icon(Icons.app_settings_alt_outlined),
          label: const Text('Open Momentum App info'),
          style: TextButton.styleFrom(foregroundColor: AppColors.accentPrimary),
        ),
      ],
    );
  }
}
