import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSlider extends StatefulWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  }) : assert(max > min);

  final int value;
  final void Function(int) onChanged;
  final int min;
  final int max;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  static const _thumbRadius = 12.0;
  static const _bubbleSize = 36.0;

  double _trackDrawWidth = 0;
  double? _dragStartX;
  int? _dragStartValue;

  int get _divisions => widget.max - widget.min;

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartValue = widget.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragStartX == null || _dragStartValue == null || _trackDrawWidth == 0) return;
    final delta = details.globalPosition.dx - _dragStartX!;
    final stepWidth = _trackDrawWidth / _divisions;
    final steps = (delta / stepWidth).round();
    final newValue = (_dragStartValue! + steps).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackDrawWidth = constraints.maxWidth - (_thumbRadius * 2);
        final fraction = (widget.value - widget.min) / _divisions.toDouble();
        final bubbleCenterX = _thumbRadius + fraction * _trackDrawWidth;
        final bubbleLeft = (bubbleCenterX - _bubbleSize / 2)
            .clamp(0.0, constraints.maxWidth - _bubbleSize);

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accentPrimary,
                inactiveTrackColor: AppColors.backgroundCard,
                thumbColor: AppColors.accentPrimary,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: _thumbRadius),
                overlayShape: SliderComponentShape.noOverlay,
                trackHeight: 4,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: widget.value.toDouble(),
                min: widget.min.toDouble(),
                max: widget.max.toDouble(),
                divisions: _divisions,
                onChanged: (v) => widget.onChanged(v.round()),
              ),
            ),
            // Value bubble — draggable, tracks thumb position
            GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              child: SizedBox(
                height: _bubbleSize,
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Positioned(
                      left: bubbleLeft,
                      child: Container(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        decoration: const BoxDecoration(
                          color: AppColors.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.value}',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.backgroundPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Min / max labels
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.min}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${widget.max}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
