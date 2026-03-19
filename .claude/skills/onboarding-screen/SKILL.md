---
name: onboarding-screen
description: >
  Use this skill when implementing any remaining onboarding or app screen for the RunFlow app.
  Triggers when the user says "implement", "build", "create", or "add" a screen such as:
  "fitness screen", "schedule screen", "health screen", "preferences screen", "watch screen",
  "recovery screen", "motivation screen", "summary screen", "creating plan screen", "home screen",
  or any onboarding step screen. Also triggers on "/onboarding-screen" command.
---

# Onboarding Screen Implementation Skill

Implements remaining RunFlow onboarding and app screens following established patterns.

## Figma File Reference

**File key:** `AzGhuMQKAmJL2UCQq3IW0S`

| Screen | Node ID | Step | File to create |
|--------|---------|------|----------------|
| onboarding/fitness | `3:354` | 2/9 | `fitness_screen.dart` |
| onboarding/schedule | `3:917` | 3/9 | `schedule_screen.dart` |
| onboarding/health | `3:1035` | 4/9 | `health_screen.dart` |
| onboarding/preferences | `4:1101` | 5/9 | `preferences_screen.dart` |
| onboarding/watch | `4:1220` | 6/9 | `watch_screen.dart` |
| onboarding/watch-yes | `114:2` | 6/9 variant | `watch_yes_screen.dart` |
| onboarding/watch-no | `4:1383` | 6/9 variant | `watch_no_screen.dart` |
| onboarding/recovery | `113:2` | 7/9 | `recovery_screen.dart` |
| onboarding/motivation | `4:1522` | 8/9 | `motivation_screen.dart` |
| onboarding/summary | `4:1619` | 9/9 | `summary_screen.dart` |
| creating-plan | `4:1778` | — | `creating_plan_screen.dart` |
| home | `4:1797` | — | `home_screen.dart` |

## Required Workflow

### Step 1 — Get the Figma design

Use `get_screenshot` with the node ID from the table above to see the screen.

```
get_screenshot(fileKey="AzGhuMQKAmJL2UCQq3IW0S", nodeId="<nodeId>")
```

If you need more structural detail, follow with `get_design_context`.

### Step 2 — Understand the design intent

Read the screenshot to identify:
- Screen title and subtitle
- All question sections and their input types
- Selection state logic (what enables the Continue button)
- Any progressive reveal (sections that appear after an answer)

**Do NOT copy exact pixel sizes from Figma.** Sizes in Figma are for a fixed 393×852 canvas — the app runs on real devices with different dimensions. Use the design tokens already defined in the project instead.

### Step 3 — Implement following project conventions

See the **Established Patterns** section below for exact code patterns to follow.

### Step 4 — Wire navigation

Add a `Navigator.push` from the previous screen's Continue button to the new screen.

---

## Established Patterns

### File location

All onboarding screens live in:
```
apps/mobile/lib/features/onboarding/presentation/screens/
```

### Standard imports

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
```

### Full screen scaffold (copy this shell for every onboarding screen)

```dart
class XxxScreen extends StatefulWidget {
  const XxxScreen({super.key});
  @override
  State<XxxScreen> createState() => _XxxScreenState();
}

class _XxxScreenState extends State<XxxScreen> {
  // state variables here

  bool get _isComplete => /* all required fields answered */;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.screen, 0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/chevron_left.svg',
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'N / 9', // replace N with the step number
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: N, total: 9), // replace N
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline
                    Text('Screen Title', style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    // Subtitle
                    Text(
                      'Screen subtitle text.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Section label
                    Text('Section label', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    // ... section content ...

                    const SizedBox(height: AppSpacing.xl), // between sections
                  ],
                ),
              ),
            ),

            // ── Continue button ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: AppButton(
                label: 'Continue',
                onPressed: _isComplete ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NextScreen()),
                  );
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Reusable UI Patterns

### Full-width single-select card (with optional subtitle)

Used in: health screen pain options, preferences guidance mode, recovery work/activity level, motivation coaching tone.

```dart
class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
```

### Pill chip (single or multi-select)

Used for: content-sized options laid out in a `Wrap` — e.g. volume ranges, run distances, benchmark options.
**Selected state: solid green bg (`accentPrimary`) + dark text (`backgroundPrimary`). NOT muted.**
**Always wrap in `IntrinsicWidth` so each chip sizes to its label, not the full screen width.**

```dart
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentPrimary : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? AppColors.backgroundPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Use `Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [...])` to lay chips out.

### Icon + label card (preferences guidance mode, fitness experience level)

Used when a card has a leading accent icon container + title + subtitle.

```dart
class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String icon; // SVG asset path
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentMuted,
                borderRadius: AppRadius.borderMd,
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.accentPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
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
}
```

### Rectangular toggle button (Yes / No / Not sure)

Used for binary or ternary answer questions — e.g. "Can you run 10 minutes?", "Can you complete goal distance?".
**Selected state: muted green bg (`accentMuted`) + green border + white text.**

```dart
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
```

Place in an `Expanded` `Row` with `SizedBox(width: AppSpacing.md)` between items:

```dart
Row(
  children: [
    Expanded(child: _ToggleButton(label: 'Yes', isSelected: _v == 'Yes', onTap: () => setState(() => _v = 'Yes'))),
    const SizedBox(width: AppSpacing.md),
    Expanded(child: _ToggleButton(label: 'No', isSelected: _v == 'No', onTap: () => setState(() => _v = 'No'))),
  ],
)
```

### Segmented control (equal-width options inside one container)

Used for: 4–6 short equal-width options — e.g. "Running days per week" (0–5+), "Race distance before" (Never/Once/2-3/4+).
**Selected state: solid green bg (`accentPrimary`) + dark text (`backgroundPrimary`). Outer container is `backgroundCard`.**

```dart
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.backgroundPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

---

## Component Selection Guide

**Always call `get_design_context` to verify the exact component before implementing.** Do not guess — the wrong component is a common source of bugs.

| What you see in Figma | Component to use |
|-----------------------|-----------------|
| Full-width card with title + subtitle, rounded rect border | `_SelectCard` |
| Large icon box + title + subtitle, rounded rect border | `_IconCard` |
| 2–3 equal full-width rectangular buttons (Yes/No, Yes/No/Not sure) | `_ToggleButton` in `Expanded` `Row` |
| 4–6 short options inside **one shared dark container**, equal widths | `_SegmentedControl` |
| Variable-width pill buttons in a **`Wrap`** (content-sized) | `_Chip` with `IntrinsicWidth` |

Key distinctions:
- **`_ToggleButton` vs `_SegmentedControl`**: toggle buttons are separate bordered cards; segmented control is segments inside one shared container with no individual borders.
- **`_SegmentedControl` vs `_Chip`**: segmented control options are equal-width inside one container; chips are content-sized and wrap to multiple rows.
- **Never use `_Chip` in an `Expanded` row** — that forces full width, use `_ToggleButton` or `_SegmentedControl` instead.

---

## Design Rules

- **Pixel sizes from Figma are reference only.** Use `AppSpacing` tokens — never hardcode pixel numbers for padding/margin.
- **Spacing between sections:** `SizedBox(height: AppSpacing.xl)` (24px)
- **Spacing between label and content:** `SizedBox(height: AppSpacing.md)` (12px)
- **Spacing between items inside a section:** `SizedBox(height: AppSpacing.sm)` (8px)
- **Continue button is always disabled** (`onPressed: null`) until all required fields are answered.
- **Progressive reveal** (like in goal_screen.dart): use `if (someState != null) ...[...]` inline in the Column to show sections after a prior answer.
- **Auto-scroll on reveal**: use `_scrollController.animateTo(maxScrollExtent)` via `addPostFrameCallback` when a new section reveals (see `goal_screen.dart` for the pattern).
- **Colors:** always `AppColors.*`, never hex.
- **Typography:** always use the direct non-nullable getters — `AppTypography.titleMedium`, `AppTypography.bodyMedium`, etc. **NEVER use `AppTypography.textTheme.*?.copyWith(...)` — the `?` makes the whole style null if the slot is unset, so color overrides silently fail.**
- **Border radius:** always `AppRadius.*` or `BorderRadius.circular(100)` for pills.

## SVG Asset Handling

### Already available — do NOT re-download these

These files already exist in `apps/mobile/assets/icons/`:

```
zap.svg            target.svg         trending_up.svg    calendar.svg
chevron_left.svg   circle_check.svg   sparkles.svg       clock.svg
flame.svg          trophy.svg         medal.svg          mountain.svg
```

Reference them directly: `'assets/icons/filename.svg'`

### Pulling new icons from Figma

If a screen needs an icon that is **not in the list above**, download it from Figma:

1. Use `get_design_context` on the screen node to get the asset download URLs returned by the Figma MCP server.
2. The MCP server returns `localhost` URLs for assets — use those URLs directly to download the file.
3. Save the SVG to `apps/mobile/assets/icons/<icon_name>.svg`.
4. Verify `apps/mobile/pubspec.yaml` already includes `assets/icons/` — it does, so no changes needed there.
5. **After downloading, strip CSS variables** — Figma exports SVGs with `var(--stroke-0, #00E676)` syntax. `flutter_svg` does NOT support CSS custom properties and will render nothing. Run:
   ```bash
   sed -i '' 's/var(--[^,]*, \(#[^)]*\))/\1/g' apps/mobile/assets/icons/<icon_name>.svg
   ```
   This replaces every `var(--x, #COLOR)` with the fallback `#COLOR` directly.

**Never** create placeholder icons or use icon packages. If the Figma MCP returns a localhost URL, use it.

## Spacing Token Reference

| Token | Value |
|-------|-------|
| `AppSpacing.xs` | 4px |
| `AppSpacing.sm` | 8px |
| `AppSpacing.md` | 12px |
| `AppSpacing.base` | 16px |
| `AppSpacing.lg` | 20px |
| `AppSpacing.xl` | 24px |
| `AppSpacing.xxl` | 32px |
| `AppSpacing.xxxl` | 40px |
| `AppSpacing.screen` | 20px |
