import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/phub_event.dart';
import '../../data/phubbing_repository.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/shared_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<PhubEvent>? _sub;

  @override
  void initState() {
    super.initState();
    final repo = context.read<PhubbingRepository>();
    _sub = repo.eventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final repo = context.watch<PhubbingRepository>();
    final today = repo.today;
    final yesterday = repo.yesterday;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildAppBar(context, b)),

            // ── Hero number ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
                ),
                child: _buildHero(today, yesterday, b),
              ),
            ),

            // ── 7-day bar chart ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildWeekChart(repo, b),
              ),
            ),

            // ── Metrics row ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildMetrics(today, b),
              ),
            ),

            // ── Monitoring toggle ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildMonitoringToggle(repo, b),
              ),
            ),

            // ── Activity feed header ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.md,
                ),
                child: SectionHeader(
                  title: 'RECENT ACTIVITY',
                  trailing: repo.recentEvents.length > 3
                      ? GestureDetector(
                          onTap: () => _showFullActivityList(context),
                          child: Text(
                            'View all',
                            style: AppTextStyles.label(AppColors.accent(b)),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // ── Activity feed ──────────────────────────────────
            if (repo.recentEvents.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.timeline_rounded,
                  title: 'No activity yet',
                  subtitle:
                      'Phubb-Free will show moments here as they happen.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverList.separated(
                  itemCount: repo.recentEvents.take(5).length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final event = repo.recentEvents[index];
                    return _EventTile(event: event);
                  },
                ),
              ),

            // ── Privacy badge ──────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: PrivacyBadge(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar with theme toggle and profile ────────────────────
  Widget _buildAppBar(BuildContext context, Brightness b) {
    final themeCtrl = context.read<ThemeController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.lg, 0,
      ),
      child: Row(
        children: [
          Text(
            'Phubb-Free',
            style: AppTextStyles.h2(AppColors.textPrimary(b)),
          ),
          const Spacer(),
          // Theme toggle
          IconButton(
            onPressed: themeCtrl.toggle,
            tooltip: 'Toggle theme',
            icon: Icon(
              b == Brightness.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              color: AppColors.textSecondary(b),
              size: 22,
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => _showProfileSheet(context, b),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentSoft(b),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: AppColors.accent(b),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero number ──────────────────────────────────────────────
  Widget _buildHero(DaySummary today, DaySummary? yesterday, Brightness b) {
    final diff = yesterday != null
        ? today.phubMoments - yesterday.phubMoments
        : 0;
    final diffText = diff < 0
        ? 'down from ${yesterday!.phubMoments} yesterday'
        : diff > 0
            ? 'up from ${yesterday!.phubMoments} yesterday'
            : yesterday != null
                ? 'same as yesterday'
                : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: today.phubMoments),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, _) {
            return Text(
              '$value',
              style: AppTextStyles.heroNumber(AppColors.textPrimary(b)),
            );
          },
        ),
        Text(
          'phubbing moments today',
          style: AppTextStyles.bodyLarge(AppColors.textSecondary(b)),
        ),
        if (diffText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            diffText,
            style: AppTextStyles.bodySmall(
              diff < 0 ? AppColors.positive(b) : AppColors.textSecondary(b),
            ),
          ),
        ],
      ],
    );
  }

  // ── 7-day bar chart ──────────────────────────────────────────
  Widget _buildWeekChart(PhubbingRepository repo, Brightness b) {
    final days = repo.dailySummaries(7).reversed.toList();
    final maxY = days.fold<int>(
            0, (max, d) => d.phubMoments > max ? d.phubMoments : max) +
        2;

    return Container(
      height: 140,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.border(b),
          width: AppSpacing.border,
        ),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY.toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: AppSpacing.radiusSm,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = days[group.x.toInt()];
                return BarTooltipItem(
                  '${DateFormat.E().format(day.date)}: ${day.phubMoments}',
                  AppTextStyles.labelSmall(AppColors.textPrimary(b)),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= days.length) {
                    return const SizedBox.shrink();
                  }
                  final day = days[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      DateFormat.E().format(day.date).substring(0, 2),
                      style: AppTextStyles.labelSmall(
                        AppColors.textSecondary(b),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(days.length, (i) {
            final isToday = i == days.length - 1;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].phubMoments.toDouble(),
                  color: isToday
                      ? AppColors.accent(b)
                      : AppColors.accentSoft(b),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  // ── Metrics grid ─────────────────────────────────────────────
  Widget _buildMetrics(DaySummary today, Brightness b) {
    String formatDuration(Duration d) {
      if (d.inHours > 0) {
        return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
      }
      return '${d.inMinutes}m';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Nudges today',
                value: '${today.nudgesSent}',
                icon: Icons.vibration_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: 'Phone-free social time',
                value: formatDuration(today.phoneFreeTime),
                icon: Icons.group_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Longest stretch',
                value: formatDuration(today.longestStretch),
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: 'Unlocks near people',
                value: '${today.unlocksNearPeople}',
                icon: Icons.lock_open_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Monitoring toggle ────────────────────────────────────────
  Widget _buildMonitoringToggle(PhubbingRepository repo, Brightness b) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
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
            repo.isMonitoring
                ? Icons.sensors_rounded
                : Icons.sensors_off_rounded,
            color: repo.isMonitoring
                ? AppColors.positive(b)
                : AppColors.textSecondary(b),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring',
                  style: AppTextStyles.body(AppColors.textPrimary(b)),
                ),
                Text(
                  repo.isMonitoring ? 'Active' : 'Paused',
                  style: AppTextStyles.bodySmall(
                    repo.isMonitoring
                        ? AppColors.positive(b)
                        : AppColors.textSecondary(b),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: repo.isMonitoring,
            onChanged: (_) => repo.toggleMonitoring(),
          ),
        ],
      ),
    );
  }

  // ── Profile bottom sheet ─────────────────────────────────────
  void _showProfileSheet(BuildContext context, Brightness b) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phubb-Free', style: AppTextStyles.h2(AppColors.textPrimary(b))),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Version 1.0.0',
                  style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'All data stays on your device. Phubb-Free uses on-device '
                  'AI to detect phubbing moments — no data is ever uploaded '
                  'to any server.',
                  style: AppTextStyles.body(AppColors.textSecondary(b)),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Navigate to settings tab
                      DefaultTabController.of(context);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Full activity list bottom sheet ──────────────────────────
  void _showFullActivityList(BuildContext context) {
    final repo = context.read<PhubbingRepository>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final b = Theme.of(ctx).brightness;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(b),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All Activity',
                        style: AppTextStyles.h2(AppColors.textPrimary(b)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      itemCount: repo.recentEvents.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        return _EventTile(event: repo.recentEvents[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Event tile widget ──────────────────────────────────────────
class _EventTile extends StatefulWidget {
  final PhubEvent event;
  const _EventTile({required this.event});

  @override
  State<_EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<_EventTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final event = widget.event;
    final icon = _iconForType(event.type);
    final timeAgo = _formatTimeAgo(event.timestamp);

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
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft(b),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.accent(b)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.friendlyText,
                          style: AppTextStyles.body(AppColors.textPrimary(b)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              timeAgo,
                              style: AppTextStyles.bodySmall(
                                AppColors.textSecondary(b),
                              ),
                            ),
                            if (event.isPossiblePhubbing) ...[
                              const SizedBox(width: AppSpacing.sm),
                              StatusTag(
                                text: 'Possible phubbing',
                                color: AppColors.warning(b),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textSecondary(b),
                  ),
                ],
              ),
            ),
          ),
          // Expandable details
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft(b).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: AppTextStyles.label(AppColors.textSecondary(b)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (event.appPackage.isNotEmpty)
                      _detailRow('Package', event.appPackage, b),
                    if (event.rssi != null)
                      _detailRow('RSSI', '${event.rssi} dBm', b),
                    if (event.responseLatencySec != null)
                      _detailRow(
                        'Response latency',
                        '${event.responseLatencySec}s',
                        b,
                      ),
                    _detailRow(
                      'Nearby person',
                      event.nearbyPersonDetected ? 'Yes' : 'No',
                      b,
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Brightness b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall(AppColors.textPrimary(b)),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(PhubEventType type) {
    switch (type) {
      case PhubEventType.unlock:
        return Icons.lock_open_rounded;
      case PhubEventType.appSwitch:
        return Icons.apps_rounded;
      case PhubEventType.notification:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat.MMMd().format(timestamp);
  }
}
