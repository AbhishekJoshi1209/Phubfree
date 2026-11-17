import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/phub_event.dart';
import '../../data/phubbing_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/shared_widgets.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _selectedDays = 7; // 7 or 30

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final repo = context.watch<PhubbingRepository>();
    final days = repo.dailySummaries(_selectedDays);
    final trend = repo.weeklyTrend;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: Text(
                  'Insights',
                  style: AppTextStyles.h1(AppColors.textPrimary(b)),
                ),
              ),
            ),

            // ── Period toggle ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildPeriodToggle(b),
              ),
            ),

            // ── Trend summary ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildTrendSummary(trend, b),
              ),
            ),

            // ── Chart ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
                ),
                child: _buildChart(days, b),
              ),
            ),

            // ── Top apps during social moments ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.md,
                ),
                child: SectionHeader(title: 'TOP APPS DURING SOCIAL MOMENTS'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverList.separated(
                itemCount: repo.topApps.length,
                separatorBuilder: (_, _) => Divider(
                  color: AppColors.border(b),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final app = repo.topApps[index];
                  return _AppRankTile(
                    rank: index + 1,
                    app: app,
                  );
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

  Widget _buildPeriodToggle(Brightness b) {
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
          Expanded(child: _periodButton('7 days', 7, b)),
          Expanded(child: _periodButton('30 days', 30, b)),
        ],
      ),
    );
  }

  Widget _periodButton(String label, int days, Brightness b) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
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
    );
  }

  Widget _buildTrendSummary(int trend, Brightness b) {
    final isDown = trend < 0;
    final trendText = isDown
        ? 'Phubbing is down ${trend.abs()}% this week'
        : trend > 0
            ? 'Phubbing is up ${trend.abs()}% this week'
            : 'Phubbing is about the same this week';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: (isDown ? AppColors.positive(b) : AppColors.warning(b))
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: (isDown ? AppColors.positive(b) : AppColors.warning(b))
              .withValues(alpha: 0.2),
          width: AppSpacing.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDown ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            color: isDown ? AppColors.positive(b) : AppColors.warning(b),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              trendText,
              style: AppTextStyles.body(AppColors.textPrimary(b)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<DaySummary> days, Brightness b) {
    final reversed = days.reversed.toList();
    final maxY = reversed.fold<int>(
            0, (max, d) => d.phubMoments > max ? d.phubMoments : max) +
        2;

    return Container(
      height: 200,
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
                final idx = group.x.toInt();
                if (idx >= reversed.length) return null;
                final day = reversed[idx];
                return BarTooltipItem(
                  '${DateFormat.MMMd().format(day.date)}\n${day.phubMoments} moments',
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
                showTitles: _selectedDays <= 7,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= reversed.length) return const SizedBox.shrink();
                  final day = reversed[idx];
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
          barGroups: List.generate(reversed.length, (i) {
            final isToday = i == reversed.length - 1;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: reversed[i].phubMoments.toDouble(),
                  color: isToday
                      ? AppColors.accent(b)
                      : AppColors.accentSoft(b),
                  width: _selectedDays <= 7 ? 20 : 6,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
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
}

class _AppRankTile extends StatelessWidget {
  final int rank;
  final AppSocialUsage app;

  const _AppRankTile({required this.rank, required this.app});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: AppTextStyles.label(AppColors.textSecondary(b)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentSoft(b),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.apps_rounded,
              size: 18,
              color: AppColors.accent(b),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              app.appName,
              style: AppTextStyles.body(AppColors.textPrimary(b)),
            ),
          ),
          Text(
            '${app.count} times',
            style: AppTextStyles.bodySmall(AppColors.textSecondary(b)),
          ),
        ],
      ),
    );
  }
}
