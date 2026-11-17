import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nudge_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A slide-down overlay banner shown when the [NudgeService] fires a nudge.
///
/// Wrap the main app scaffold with this widget so it appears over all tabs.
/// It auto-dismisses after 4 seconds or when the user taps it.
class NudgeOverlay extends StatelessWidget {
  final Widget child;

  const NudgeOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final nudge = context.watch<NudgeService>();

    return Stack(
      children: [
        child,
        // The banner slides in from the top.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          top: nudge.overlayVisible
              ? MediaQuery.of(context).padding.top + AppSpacing.md
              : -(120 + MediaQuery.of(context).padding.top),
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          child: GestureDetector(
            onTap: nudge.dismissOverlay,
            onVerticalDragEnd: (_) => nudge.dismissOverlay,
            child: _NudgeBanner(
              message: nudge.overlayMessage,
              visible: nudge.overlayVisible,
            ),
          ),
        ),
      ],
    );
  }
}

class _NudgeBanner extends StatelessWidget {
  final String message;
  final bool visible;

  const _NudgeBanner({required this.message, required this.visible});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1.0 : 0.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            // Glassmorphic card with accent tint.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent(b).withValues(alpha: 0.92),
                AppColors.accent(b).withValues(alpha: 0.80),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent(b).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulse dot.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.onAccent(b),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onAccent(b).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body(AppColors.onAccent(b)).copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.close_rounded,
                color: AppColors.onAccent(b).withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
