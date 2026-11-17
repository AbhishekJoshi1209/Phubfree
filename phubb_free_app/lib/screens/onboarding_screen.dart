import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/permission_service.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// 3-screen onboarding flow explaining why each permission is needed.
/// Shown on first run only. Skippable. Re-openable from Settings.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final permService = context.watch<PermissionService>();

    final pages = [
      _OnboardingPage(
        icon: Icons.app_settings_alt_rounded,
        title: 'Usage Access',
        description:
            'Phubb-Free needs to detect when you unlock your phone and '
            'switch between apps. This helps identify moments when you '
            'might be phubbing someone nearby.',
        detail:
            'We only track screen on/off and app switches — '
            'never what you type or view.',
        isGranted: permService.usageAccessGranted,
        onGrant: permService.requestUsageAccess,
      ),
      _OnboardingPage(
        icon: Icons.bluetooth_rounded,
        title: 'Bluetooth',
        description:
            'Bluetooth lets Phubb-Free sense when other people are '
            'physically nearby. It scans for nearby devices to estimate '
            'social proximity — it never connects to them.',
        detail: 'No data about other devices is stored or sent anywhere.',
        isGranted: permService.bluetoothGranted,
        onGrant: permService.requestBluetooth,
      ),
      _OnboardingPage(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        description:
            'We use notification access to measure response latency — '
            'how quickly you react to incoming alerts. This helps the AI '
            'model understand your phone-checking habits.',
        detail: 'We never read notification content. Only timestamps.',
        isGranted: permService.notificationAccessGranted,
        onGrant: permService.requestNotificationAccess,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.button(AppColors.textSecondary(b)),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),

            // Page indicators + next button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: Row(
                children: [
                  // Dots
                  ...List.generate(pages.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.accent(b)
                            : AppColors.border(b),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),
                  // Next / Done button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finish();
                        }
                      },
                      child: Text(
                        _currentPage < pages.length - 1
                            ? 'Next'
                            : 'Get started',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    context.read<SettingsController>().completeOnboarding();
    widget.onComplete();
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String detail;
  final bool isGranted;
  final VoidCallback onGrant;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.detail,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accentSoft(b),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(icon, size: 36, color: AppColors.accent(b)),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Title
          Text(
            title,
            style: AppTextStyles.h1(AppColors.textPrimary(b)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Description
          Text(
            description,
            style: AppTextStyles.bodyLarge(AppColors.textSecondary(b)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),

          // Privacy detail
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accentSoft(b).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.accent(b),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    detail,
                    style: AppTextStyles.bodySmall(AppColors.accent(b)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Grant button or granted check
          if (isGranted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.positive(b),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Granted',
                  style: AppTextStyles.button(AppColors.positive(b)),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onGrant,
                child: const Text('Grant permission'),
              ),
            ),
        ],
      ),
    );
  }
}
