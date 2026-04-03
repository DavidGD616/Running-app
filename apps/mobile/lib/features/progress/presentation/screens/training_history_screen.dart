import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import '../../../../core/widgets/stat_column.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../../domain/models/training_history_point.dart';
import '../progress_provider.dart';

class TrainingHistoryScreen extends ConsumerStatefulWidget {
  const TrainingHistoryScreen({super.key});

  @override
  ConsumerState<TrainingHistoryScreen> createState() =>
      _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends ConsumerState<TrainingHistoryScreen> {
  TrainingHistoryRange _selectedRange = TrainingHistoryRange.month;
  int? _selectedIndex;

  void _handleRangeChanged(int index) {
    setState(() {
      _selectedRange = TrainingHistoryRange.values[index];
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitPrefs = ref.watch(userPreferencesProvider);
    final unitSystem = unitPrefs.value?.unitSystem ?? UnitSystem.km;
    final points = ref.watch(trainingHistorySeriesProvider(_selectedRange));
    final selectedIndex = points.isEmpty
        ? 0
        : (_selectedIndex ?? points.length - 1).clamp(0, points.length - 1);
    final selectedPoint = points.isEmpty ? null : points[selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.trainingHistoryTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedPoint != null)
                _SelectedPeriodSummaryCard(
                  point: selectedPoint,
                  unitSystem: unitSystem,
                  l10n: l10n,
                ),

              const SizedBox(height: AppSpacing.md),

              _TrainingHistoryChartCard(
                title: l10n.weekProgressVolumeLabel,
                points: points,
                unitSystem: unitSystem,
                selectedIndex: selectedIndex,
                onSelectedIndexChanged: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),

              const SizedBox(height: AppSpacing.md),

              AppSegmentedControl(
                options: const ['1W', '1M', '3M', '6M', '1Y', 'All'],
                selectedIndex: _selectedRange.index,
                onChanged: _handleRangeChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPeriodSummaryCard extends StatelessWidget {
  const _SelectedPeriodSummaryCard({
    required this.point,
    required this.unitSystem,
    required this.l10n,
  });

  final TrainingHistoryPoint point;
  final UnitSystem unitSystem;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  point.label,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (point.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderFull,
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    l10n.fullPlanCurrentBadge,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                StatColumn(
                  label: l10n.progressDistanceLabel,
                  value: UnitFormatter.formatDistanceWithUnit(
                    point.distanceKm,
                    unitSystem,
                  ),
                ),
                StatColumn(
                  label: l10n.progressTimeLabel,
                  value: UnitFormatter.formatDuration(point.durationMinutes),
                  hasDivider: true,
                ),
                StatColumn(
                  label: l10n.progressElevationLabel,
                  value: '${point.elevationMeters} m',
                  hasDivider: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingHistoryChartCard extends StatelessWidget {
  const _TrainingHistoryChartCard({
    required this.title,
    required this.points,
    required this.unitSystem,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final String title;
  final List<TrainingHistoryPoint> points;
  final UnitSystem unitSystem;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  double _maxValue(List<double> values) {
    final peak = values.fold<double>(0, math.max);
    if (peak <= 0) {
      return unitSystem == UnitSystem.km ? 10 : 6;
    }

    final raw = peak * 1.2;
    final step = raw <= 5
        ? 1.0
        : raw <= 20
        ? 2.0
        : raw <= 50
        ? 5.0
        : 10.0;
    return (raw / step).ceil() * step;
  }

  String _formatAxisValue(double value) {
    final isWhole = value == value.roundToDouble();
    final text = isWhole ? value.round().toString() : value.toStringAsFixed(1);
    return '$text ${UnitFormatter.unitLabel(unitSystem)}';
  }

  void _updateSelection(double localX, double chartWidth) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      onSelectedIndexChanged(0);
      return;
    }

    int nearest = 0;
    double minDistance = double.infinity;
    for (int index = 0; index < points.length; index++) {
      final pointX = chartWidth * index / (points.length - 1);
      final distance = (pointX - localX).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearest = index;
      }
    }

    if (nearest != selectedIndex) {
      onSelectedIndexChanged(nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayValues = points
        .map(
          (point) => UnitFormatter.distanceValue(point.distanceKm, unitSystem),
        )
        .toList(growable: false);
    final maxValue = _maxValue(displayValues);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1E1E), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAxisValue(maxValue),
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      _formatAxisValue(maxValue / 2),
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      _formatAxisValue(0),
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _updateSelection(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        onHorizontalDragUpdate: (details) => _updateSelection(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        child: CustomPaint(
                          painter: _TrainingHistoryChartPainter(
                            data: displayValues,
                            selectedIndex: selectedIndex,
                            maxValue: maxValue,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingHistoryChartPainter extends CustomPainter {
  const _TrainingHistoryChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.maxValue,
  });

  final List<double> data;
  final int selectedIndex;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double yFor(double value) => size.height * (1 - (value / maxValue));
    double xFor(int index) => data.length == 1
        ? size.width / 2
        : size.width * index / (data.length - 1);

    final points = List.generate(
      data.length,
      (index) => Offset(xFor(index), yFor(data[index])),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 0.5;
    for (final y in [0.0, size.height / 2, size.height]) {
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          AppColors.accentPrimary.withValues(alpha: 0.25),
          AppColors.accentPrimary.withValues(alpha: 0),
        ]);
      canvas.drawPath(fillPath, fillPaint);

      final linePaint = Paint()
        ..color = AppColors.accentPrimary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        linePath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    final selectedPoint = points[selectedIndex];
    final dashLinePaint = Paint()
      ..color = AppColors.accentPrimary.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    _drawDashedLine(
      canvas,
      Offset(selectedPoint.dx, selectedPoint.dy),
      Offset(selectedPoint.dx, size.height),
      dashLinePaint,
    );

    for (int index = 0; index < data.length; index++) {
      final isSelected = index == selectedIndex;
      final center = points[index];

      if (isSelected) {
        canvas.drawCircle(
          center,
          5.5,
          Paint()..color = AppColors.accentPrimary,
        );
      } else {
        canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF1A1A1A));
        canvas.drawCircle(
          center,
          4,
          Paint()
            ..color = AppColors.accentPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;

    final direction = (end - start) / totalLength;
    double distance = 0;
    while (distance < totalLength) {
      final dashEnd = math.min(distance + dashWidth, totalLength);
      canvas.drawLine(
        start + direction * distance,
        start + direction * dashEnd,
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_TrainingHistoryChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.maxValue != maxValue;
}
