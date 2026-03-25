---
name: app-screens
description: >
  Use this skill when implementing any main app screen for the RunFlow app (post-onboarding).
  Triggers when the user says "implement", "build", "create", or "add" a screen such as:
  "plan ready screen", "pre-run screen", "log run screen", "weekly plan screen",
  "session detail screen", "progress screen", "settings screen",
  or any post-onboarding app screen. Also triggers on "/app-screens" command.
---

# App Screens Implementation Skill

Implements remaining RunFlow post-onboarding app screens following established patterns.

## Figma File Reference

**File key:** `AzGhuMQKAmJL2UCQq3IW0S`

| Screen | Node ID | Feature folder | File to create |
|--------|---------|---------------|----------------|
| plan-ready | `154:561` | `plan/` | `plan_ready_screen.dart` |
| pre-run | `158:1596` | `training/` | `pre_run_screen.dart` |
| log-run | `161:1835` | `training/` | `log_run_screen.dart` |
| weekly-plan | `173:3` | `home/` | `weekly_plan_screen.dart` |
| session-detail | `182:3` | `training/` | `session_detail_screen.dart` |
| progress | `183:3` | `progress/` | `progress_screen.dart` |
| settings | `184:3` | `settings/` | `settings_screen.dart` |

## Required Workflow

### Step 1 — Get the Figma design

Use `get_screenshot` with the node ID from the table above to see the screen visually:

```
get_screenshot(fileKey="AzGhuMQKAmJL2UCQq3IW0S", nodeId="<nodeId>")
```

Then follow with `get_design_context` for structural detail (layout hierarchy, component names, colors):

```
get_design_context(fileKey="AzGhuMQKAmJL2UCQq3IW0S", nodeId="<nodeId>")
```

### Step 2 — Understand the design intent

From the screenshot and design context, identify:
- Screen layout type (scrollable list, tabbed, grid, fixed sections)
- Navigation pattern (back arrow only, bottom tab bar, modal, etc.)
- All data sections and how data flows in
- Any interactive elements (toggles, buttons, inputs)
- Whether the screen needs state management (Riverpod) or is purely presentational

**Do NOT copy pixel sizes from Figma.** Use project design tokens exclusively.

### Step 3 — Determine the correct file location

App screens go in feature-specific subfolders:

```
apps/mobile/lib/features/<feature>/presentation/screens/<screen_name>.dart
```

If the feature folder does not yet exist, create the full path:
```
features/<feature>/
  presentation/
    screens/
      <screen_name>.dart
```

### Step 4 — Implement following project conventions

See the **Established Patterns** and **Reusable UI Patterns** sections below.

### Step 5 — Wire navigation

Connect from the previous screen or bottom nav bar. Use `Navigator.push` for stack navigation or update the router config if adding a new named route.

---

## Established Patterns

### Standard imports

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
```

Add Riverpod imports if state management is needed:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

### Stateless app screen (no user input)

Use when the screen only displays data and has no interactive selections:

```dart
class XxxScreen extends StatelessWidget {
  const XxxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              child: Row(
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
                  const SizedBox(width: AppSpacing.sm),
                  Text('Screen Title', style: AppTypography.titleLarge),
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
                    // content here
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Stateful app screen (has user input or selections)

Use when the screen has toggles, inputs, or selections that affect what is displayed or submitted:

```dart
class XxxScreen extends StatefulWidget {
  const XxxScreen({super.key});
  @override
  State<XxxScreen> createState() => _XxxScreenState();
}

class _XxxScreenState extends State<XxxScreen> {
  // state variables here

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // top nav + content + action button
          ],
        ),
      ),
    );
  }
}
```

### Riverpod consumer screen (reads shared app state)

Use when the screen depends on onboarding data, user preferences, or training plan state:

```dart
class XxxScreen extends ConsumerWidget {
  const XxxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // final data = ref.watch(someProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      // ...
    );
  }
}
```

---

## Reusable UI Patterns

All patterns below are private widget classes defined at the bottom of the screen file (not in separate files).

### Full-width single-select card (with optional subtitle)

Used for: settings options, single-select lists, plan options.

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

### Icon + label card

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

### Pill chip (single or multi-select)

Used for: content-sized options in a `Wrap` — tags, filters, day selectors.
**Selected state: solid green bg (`accentPrimary`) + dark text. Always wrap in `IntrinsicWidth`.**

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

### Rectangular toggle button (Yes / No / binary)

Used for binary or ternary questions. **Selected: muted green bg + green border.**

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
            textAlign: TextAlign.center,
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

Place in an `Expanded` `Row` with `SizedBox(width: AppSpacing.md)` between items.

### Segmented control (equal-width options in one container)

Used for: 4–6 short equal-width tabs — e.g. week filters, stat period selectors.
**Selected: solid green bg (`accentPrimary`) + dark text. Outer container is `backgroundCard`.**

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

### Stat / metric tile

Used for progress and session detail screens to display a labeled number:

```dart
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.headlineMedium),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

Layout with a 2-column grid using `Row` + `Expanded` pairs, separated by `SizedBox(width: AppSpacing.sm)`.

---

## Component Selection Guide

Always call `get_design_context` to verify the exact component before implementing.

| What you see in Figma | Component to use |
|-----------------------|-----------------|
| Full-width card with title + subtitle, rounded rect border | `_SelectCard` |
| Large icon box + title + subtitle, rounded rect border | `_IconCard` |
| 2–3 equal full-width rectangular buttons (Yes/No) | `_ToggleButton` in `Expanded` `Row` |
| 4–6 short options inside one shared dark container | `_SegmentedControl` |
| Variable-width pill buttons in a `Wrap` | `_Chip` with `IntrinsicWidth` |
| Single number + label + optional unit | `_StatTile` |

Key distinctions:
- **`_ToggleButton` vs `_SegmentedControl`**: toggle buttons are separate bordered cards; segmented control is segments inside one shared container with no individual borders.
- **`_SegmentedControl` vs `_Chip`**: segmented control options are equal-width inside one container; chips are content-sized and wrap to multiple rows.
- **Never use `_Chip` in an `Expanded` row** — that forces full width. Use `_ToggleButton` or `_SegmentedControl` instead.

---

## Design Rules

- **Pixel sizes from Figma are reference only.** Use `AppSpacing` tokens — never hardcode pixel numbers for padding/margin.
- **Spacing between sections:** `SizedBox(height: AppSpacing.xl)` (24px)
- **Spacing between label and content:** `SizedBox(height: AppSpacing.md)` (12px)
- **Spacing between items inside a section:** `SizedBox(height: AppSpacing.sm)` (8px)
- **Colors:** always `AppColors.*`, never hex.
- **Typography:** always use direct non-nullable getters — `AppTypography.titleMedium`, `AppTypography.bodyMedium`, etc. **NEVER use `AppTypography.textTheme.*?.copyWith(...)` — the `?` makes the whole style null if the slot is unset.**
- **Border radius:** always `AppRadius.*` or `BorderRadius.circular(100)` for pills.
- **Localization:** always use `AppLocalizations.of(context)!` for any user-facing text. Add new keys to both `app_en.arb` and `app_es.arb`, then run `flutter gen-l10n` before using them.

---

## SVG Asset Handling

### Already available — do NOT re-download these

These files already exist in `apps/mobile/assets/icons/`:

```
zap.svg            target.svg         trending_up.svg    calendar.svg
chevron_left.svg   circle_check.svg   sparkles.svg       clock.svg
flame.svg          trophy.svg         medal.svg          mountain.svg
effort.svg         pace.svg           heart_rate.svg     decide_for_me.svg
heart.svg          moon.svg           edit.svg
```

Reference them directly: `'assets/icons/filename.svg'`

### Pulling new icons from Figma

If a screen needs an icon that is **not in the list above**, download it from Figma:

1. Use `get_design_context` on the screen node to get asset download URLs returned by the Figma MCP.
2. The MCP server returns `localhost` or `figma.com/api/mcp/asset/...` URLs — use those directly.
3. Save the SVG to `apps/mobile/assets/icons/<icon_name>.svg`.
4. Verify `apps/mobile/pubspec.yaml` already includes `assets/icons/` — it does.
5. **Strip CSS variables after downloading** — Figma exports SVGs with `var(--stroke-0, #00E676)` syntax. `flutter_svg` does NOT support CSS custom properties. Run:
   ```bash
   sed -i '' 's/var(--[^,]*, \(#[^)]*\))/\1/g' apps/mobile/assets/icons/<icon_name>.svg
   ```

---

## Adding Localization Keys

When a screen needs new strings:

1. Add the key + English value to `apps/mobile/lib/l10n/app_en.arb`
2. Add the key + Spanish value to `apps/mobile/lib/l10n/app_es.arb`
3. Run `flutter gen-l10n` from `apps/mobile/` before using the key in Dart code
4. Access with `AppLocalizations.of(context)!.<keyName>`

For parametrized strings (with placeholders):
```json
"myKey": "Hello {name}, you ran {distance} km",
"@myKey": {
  "placeholders": {
    "name": { "type": "String" },
    "distance": { "type": "String" }
  }
}
```

---

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
