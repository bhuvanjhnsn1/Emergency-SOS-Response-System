import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Animated timeline widget showing emergency protocol phases
class EmergencyTimeline extends StatelessWidget {
  final int currentStep; // 0=idle, 1=GPS, 2=SMS, 3=Call, 4=Done
  final bool hasError;

  const EmergencyTimeline({
    super.key,
    required this.currentStep,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.surfaceBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMERGENCY PROTOCOL',
            style: TextStyle(
              color: AppColors.accentRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            index: 1,
            icon: Icons.gps_fixed_rounded,
            label: 'Acquiring GPS Lock',
            isActive: currentStep == 1,
            isCompleted: currentStep > 1,
          ),
          _buildConnector(isCompleted: currentStep > 1),
          _buildStep(
            index: 2,
            icon: Icons.sms_rounded,
            label: 'Sending Emergency SMS',
            isActive: currentStep == 2,
            isCompleted: currentStep > 2,
          ),
          _buildConnector(isCompleted: currentStep > 2),
          _buildStep(
            index: 3,
            icon: Icons.call_rounded,
            label: 'Dialing Emergency Contact',
            isActive: currentStep == 3,
            isCompleted: currentStep > 3,
          ),
          _buildConnector(isCompleted: currentStep > 3),
          _buildStep(
            index: 4,
            icon: Icons.track_changes_rounded,
            label: 'Live Movement Tracking',
            isActive: currentStep == 4,
            isCompleted: currentStep > 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isCompleted
        ? AppColors.accentGreen
        : isActive
            ? AppColors.accentOrange
            : AppColors.textMuted;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 2),
          ),
          child: isCompleted
              ? Icon(Icons.check_rounded, color: color, size: 18)
              : isActive
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isActive || isCompleted
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (isCompleted)
          const Text(
            '✓',
            style: TextStyle(color: AppColors.accentGreen, fontSize: 16),
          ),
      ],
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Container(
        width: 2,
        height: 24,
        color: isCompleted
            ? AppColors.accentGreen.withValues(alpha: 0.5)
            : AppColors.surfaceBorder,
      ),
    );
  }
}
