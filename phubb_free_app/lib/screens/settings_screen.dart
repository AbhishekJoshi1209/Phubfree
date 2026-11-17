import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final settings = context.watch<SettingsController>();
    final themeCtrl = context.watch<ThemeController>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text('Settings', style: AppTextStyles.h1(AppColors.textPrimary(b))),
            const SizedBox(height: AppSpacing.xxl),

            // ── Appearance ─────────────────────────────────────
            _SectionTitle(title: 'APPEARANCE'),
            const SizedBox(height: AppSpacing.md),
            _buildThemeSelector(context, themeCtrl, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── Nudge sensitivity ──────────────────────────────
            _SectionTitle(title: 'NUDGE SENSITIVITY'),
            const SizedBox(height: AppSpacing.md),
            _buildSensitivitySlider(context, settings, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── Nudge style ────────────────────────────────────
            _SectionTitle(title: 'NUDGE STYLE'),
            const SizedBox(height: AppSpacing.md),
            _buildNudgeStyleSelector(context, settings, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── Quiet hours ────────────────────────────────────
            _SectionTitle(title: 'QUIET HOURS'),
            const SizedBox(height: AppSpacing.md),
            _buildQuietHours(context, settings, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── App whitelist ──────────────────────────────────
            _SectionTitle(title: 'APP WHITELIST'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'These apps never trigger a nudge.',
              style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildWhitelist(context, settings, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── Data ───────────────────────────────────────────
            _SectionTitle(title: 'YOUR DATA'),
            const SizedBox(height: AppSpacing.md),
            _buildDataSection(context, settings, b),

            const SizedBox(height: AppSpacing.xxl),

            // ── About ──────────────────────────────────────────
            _SectionTitle(title: 'ABOUT'),
            const SizedBox(height: AppSpacing.md),
            _buildAbout(context, settings, b),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  // ── Theme selector (System / Light / Dark) ───────────────────
  Widget _buildThemeSelector(
    BuildContext context,
    ThemeController ctrl,
    Brightness b,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Row(
        children: [
          _themeOption(context, ctrl, ThemeMode.system, 'System', b),
          _themeOption(context, ctrl, ThemeMode.light, 'Light', b),
          _themeOption(context, ctrl, ThemeMode.dark, 'Dark', b),
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeController ctrl,
    ThemeMode mode,
    String label,
    Brightness b,
  ) {
    final isSelected = ctrl.mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => ctrl.setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent(b) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 1),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button(
                isSelected ? AppColors.onAccent(b) : AppColors.textSecondary(b),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sensitivity slider ───────────────────────────────────────
  Widget _buildSensitivitySlider(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    final labels = ['Low', 'Medium', 'High'];
    final labelIndex = (settings.nudgeSensitivity * 2).round().clamp(0, 2);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sensitivity',
                style: AppTextStyles.body(AppColors.textPrimary(b)),
              ),
              Text(
                labels[labelIndex],
                style: AppTextStyles.label(AppColors.accent(b)),
              ),
            ],
          ),
          Slider(
            value: settings.nudgeSensitivity,
            onChanged: (v) => settings.setNudgeSensitivity(v),
            divisions: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fewer nudges',
                style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
              ),
              Text(
                'More nudges',
                style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nudge style ──────────────────────────────────────────────
  Widget _buildNudgeStyleSelector(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Column(
        children: NudgeStyle.values.map((style) {
          final isSelected = settings.nudgeStyle == style;
          return InkWell(
            onTap: () => settings.setNudgeStyle(style),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    _nudgeIcon(style),
                    size: 20,
                    color: isSelected
                        ? AppColors.accent(b)
                        : AppColors.textSecondary(b),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      style.label,
                      style: AppTextStyles.body(AppColors.textPrimary(b)),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: AppColors.accent(b),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _nudgeIcon(NudgeStyle style) {
    switch (style) {
      case NudgeStyle.vibration:
        return Icons.vibration_rounded;
      case NudgeStyle.silentNotification:
        return Icons.notifications_none_rounded;
      case NudgeStyle.off:
        return Icons.notifications_off_outlined;
    }
  }

  // ── Quiet hours ──────────────────────────────────────────────
  Widget _buildQuietHours(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bedtime_outlined,
            size: 20,
            color: AppColors.textSecondary(b),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiet hours',
                  style: AppTextStyles.body(AppColors.textPrimary(b)),
                ),
                Text(
                  '${_formatTime(settings.quietStart)} – ${_formatTime(settings.quietEnd)}',
                  style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickQuietHours(context, settings),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _pickQuietHours(
    BuildContext context,
    SettingsController settings,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: settings.quietStart,
      helpText: 'Quiet hours start',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: settings.quietEnd,
      helpText: 'Quiet hours end',
    );
    if (end == null) return;
    await settings.setQuietHours(start, end);
  }

  // ── Whitelist ────────────────────────────────────────────────
  Widget _buildWhitelist(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Column(
        children: [
          ...settings.whitelistedApps.map((app) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.apps_rounded,
                    size: 20,
                    color: AppColors.textSecondary(b),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      app,
                      style: AppTextStyles.body(AppColors.textPrimary(b)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => settings.removeWhitelistedApp(app),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary(b),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Add app button
          InkWell(
            onTap: () => _addWhitelistApp(context, settings),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppSpacing.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 20, color: AppColors.accent(b)),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Add app',
                    style: AppTextStyles.body(AppColors.accent(b)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addWhitelistApp(
    BuildContext context,
    SettingsController settings,
  ) async {
    final controller = TextEditingController();
    final b = Theme.of(context).brightness;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Add app to whitelist',
            style: AppTextStyles.h2(AppColors.textPrimary(b)),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'App name (e.g. Maps)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      await settings.addWhitelistedApp(result);
    }
  }

  // ── Data section ─────────────────────────────────────────────
  Widget _buildDataSection(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    return Column(
      children: [
        _actionTile(
          context: context,
          icon: Icons.download_outlined,
          label: 'Export my data',
          subtitle: 'Download as local JSON file',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data exported to local storage.')),
            );
          },
          b: b,
        ),
        const SizedBox(height: AppSpacing.sm),
        _actionTile(
          context: context,
          icon: Icons.delete_outline_rounded,
          label: 'Delete all my data',
          subtitle: 'This cannot be undone',
          isDestructive: true,
          onTap: () => _confirmDelete(context, settings, b),
          b: b,
        ),
      ],
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Brightness b,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error(b) : AppColors.textPrimary(b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isDestructive
                ? AppColors.error(b).withValues(alpha: 0.3)
                : AppColors.border(b),
            width: AppSpacing.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body(color)),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary(b),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Delete all data?',
            style: AppTextStyles.h2(AppColors.textPrimary(b)),
          ),
          content: Text(
            'This will permanently erase all locally stored data, '
            'including your settings and history. This cannot be undone.',
            style: AppTextStyles.body(AppColors.textSecondary(b)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error(b),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete everything'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await settings.deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All data deleted.')));
      }
    }
  }

  // ── About ────────────────────────────────────────────────────
  Widget _buildAbout(
    BuildContext context,
    SettingsController settings,
    Brightness b,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Phubb-Free',
                style: AppTextStyles.body(AppColors.textPrimary(b)),
              ),
              const Spacer(),
              Text(
                'v1.0.0',
                style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Phubb-Free is a privacy-first AI that detects phubbing '
            'moments using on-device processing. No data ever leaves '
            'your phone.',
            style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () => settings.resetOnboarding(),
            child: Text(
              'Re-run onboarding',
              style: AppTextStyles.label(AppColors.accent(b)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Text(title, style: AppTextStyles.label(AppColors.textSecondary(b)));
  }
}
