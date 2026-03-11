# Running App — Penpot Design System Rules

These rules define how to design screens and components for this project using Penpot. They must be followed for every screen, component, and prototype created in Penpot.

---

## Project Context

- **Platform:** Native mobile (iOS and Android, built with Flutter 3.x using Material 3)
- **Design tool:** Penpot (open-source, self-hosted or cloud at design.penpot.app)
- **Localization:** Spanish (primary) and English — all text must work naturally in both languages. UI labels should be tested at 1.3× character expansion for Spanish.
- **Visual mode:** Dark mode first (primary and default). Light mode is out of scope for MVP.
- **Target users:** Beginner to intermediate runners training for races (5K to marathon)
- **Screen sizes:** Design at 390×844pt (iPhone 14 / Pixel 7 equivalent). Test layouts at 360×780pt (small) and 428×926pt (large).
- **Export format:** SVG assets exported from Penpot; icons as individual SVGs at 24×24px

---

## Design Personality

The app should feel:
- Clean and athletic
- Premium but simple
- Modern and motivating
- Easy to scan and fast to use on mobile
- Calm, not cluttered or overly technical
- Focused on clarity and momentum

---

## Color System

### Backgrounds
| Token | Hex | Usage |
|-------|-----|-------|
| Background Primary | `#121212` | Main screen background |
| Background Secondary | `#1E1E1E` | Grouped sections, secondary areas |
| Background Card | `#2A2A2A` | Cards, selectable tiles |

### Surfaces
| Token | Hex | Usage |
|-------|-----|-------|
| Surface Elevated | `#333333` | Elevated containers, bottom sheets |

### Text
| Token | Hex | Usage |
|-------|-----|-------|
| Text Primary | `#FFFFFF` | Headings, primary content |
| Text Secondary | `#B3B3B3` | Descriptions, helper text |
| Text Disabled | `#666666` | Disabled labels, placeholders |

### Semantic
| Token | Hex | Usage |
|-------|-----|-------|
| Success | `#4CAF50` | Completed states, positive feedback |
| Warning | `#FFC107` | Caution messages |
| Error | `#EF5350` | Validation errors, destructive actions |
| Info | `#42A5F5` | Informational highlights |

### Borders
| Token | Hex | Usage |
|-------|-----|-------|
| Border Default | `#3A3A3A` | Card borders, dividers |
| Border Focused | Accent color | Focused inputs, selected states |

### Brand / Accent
| Token | Hex | Usage |
|-------|-----|-------|
| Accent Primary | `#00E676` | CTAs, selected states, progress fill, interactive highlights |
| Accent Light | `#69F0AE` | Hover/pressed tints, secondary highlights, accent text on dark |
| Accent Muted | `#00E67633` | 20% opacity accent — selection backgrounds, subtle tints |

- Accent Primary passes WCAG AA contrast on `#121212` (ratio ≥ 7:1)
- Never place Accent on white or light backgrounds
- Use Accent Muted (`#00E67633`) for selected card backgrounds
- In Flutter, map to `ColorScheme.primary` and `ColorScheme.primaryContainer`

IMPORTANT: Every color used in any design must come from these tokens. Never use arbitrary hex values. In Penpot, define all tokens as shared library colors so every component references them.

---

## Typography Scale

Font family: **Inter** (Google Fonts, variable weight). Fallback: system sans-serif.
In Flutter: `google_fonts` package → `GoogleFonts.inter()`.
In Penpot: install Inter as a custom font in the project workspace.

| Style | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| Headline Large | 28px | 700 (Bold) | 36px | -0.5px | Screen titles, hero text |
| Headline Medium | 22px | 600 (SemiBold) | 28px | -0.3px | Section headers |
| Title Large | 18px | 600 (SemiBold) | 24px | 0px | Card titles, prominent labels |
| Title Medium | 16px | 600 (SemiBold) | 22px | 0px | Sub-section headers |
| Body Large | 16px | 400 (Regular) | 24px | 0.1px | Primary body text, descriptions |
| Body Medium | 14px | 400 (Regular) | 20px | 0.15px | Secondary body text, helper copy |
| Label Large | 14px | 600 (SemiBold) | 20px | 0.1px | Button text, tab labels |
| Label Medium | 12px | 500 (Medium) | 16px | 0.5px | Chips, small interactive labels |
| Caption | 11px | 400 (Regular) | 16px | 0.4px | Timestamps, fine print, metadata |

### Rules
- All text on dark backgrounds must use Text Primary (`#FFFFFF`) or Text Secondary (`#B3B3B3`) colors
- Disabled text uses Text Disabled (`#666666`)
- Never use more than 3 typography levels on a single screen
- Maintain clear visual hierarchy: title → description → content → CTA
- All copy must read naturally in both Spanish and English — avoid sentence fragments or concatenated text
- In Penpot, save each style as a shared text style (e.g., "Headline Large / White", "Body Medium / Secondary")
- Numbers in data displays (pace, distance) use tabular figures (`font-feature-settings: 'tnum'`)

---

## Spacing Scale

Use a consistent spacing system across all screens and components:

| Token | Value | Usage |
|-------|-------|-------|
| XS | 4px | Tight internal spacing |
| SM | 8px | Small gaps between related elements |
| MD | 12px | Medium internal padding |
| Base | 16px | Default content spacing |
| LG | 20px | Section spacing |
| XL | 24px | Large section gaps |
| XXL | 32px | Major section breaks |
| XXXL | 40px | Top-of-screen spacing |
| Screen Padding | 20px | Horizontal padding on all screens |

IMPORTANT: All spacing must use these values. Never use arbitrary pixel values.

---

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| SM | 8px | Small elements (chips, badges) |
| MD | 12px | Medium elements (inputs, small cards) |
| LG | 16px | Standard cards, buttons |
| XL | 20px | Large cards, modals |
| Full | 999px | Pills, fully rounded elements |

---

## Component Library

Design these reusable components before building screens. Each component must have defined default, hover/pressed, disabled, and (where applicable) selected states.

### Buttons

**Primary Button**
- Full-width
- Accent background color
- White label text (Label Large)
- Minimum height: 48px
- Border radius: LG (16px)
- States: default, pressed, disabled (reduced opacity)

**Secondary Button**
- Full-width or auto-width
- Transparent background with accent border, or text-only variant
- Accent label text
- Minimum height: 48px
- States: default, pressed, disabled

### Cards

**Choice Card** (used in onboarding)
- Background: Background Card
- Border radius: LG (16px)
- Padding: Base (16px)
- Default state: subtle border (Border Default)
- Selected state: accent border or accent background tint
- Must show clear selected vs unselected distinction

**Session Card** (training session display)
- Shows: day, session type, duration/distance, guidance target
- Background: Background Card
- Completion status indicator

**Weekly Calendar Card**
- Shows 7 days with session type indicators
- Highlights current day and completed sessions

### Chips

**App Chip**
- Used for: day selection, tags, filters
- Border radius: Full (pill shape)
- States: default, selected (accent fill)
- Minimum tap target: 48px height

### Inputs

**Text Field**
- Background: Background Secondary or Background Card
- Border: Border Default, Border Focused on focus
- Border radius: MD (12px)
- Padding: Base (16px)
- Error state: Error color border + error message below
- Label above field, placeholder inside

**Date Picker Trigger**
- Looks like a tappable input field
- Displays selected date or placeholder
- Opens native date picker on tap

**Time Picker Input**
- Numeric input or wheel-style picker
- Clear format display (e.g., HH:MM)

### Selectors

**Segmented Control**
- Used for: units (mi/km), gender, short option sets
- 2–4 segments maximum
- Selected segment: accent fill
- Unselected: Background Card
- Large tap targets

### Indicators

**Progress Bar**
- Thin horizontal bar at top of onboarding screens
- Shows current step / total steps
- Accent color fill, Background Secondary track

### Navigation

**Top Nav Bar**
- Back arrow (left)
- Optional progress indicator (center or below)
- Clean, minimal — no extra chrome
- Background: transparent or Background Primary

### Sheets

**Bottom Sheet**
- Background: Surface Elevated
- Border radius: XL (20px) on top corners
- Drag handle indicator at top
- Content padding: Screen Padding (20px)

---

## Screen Layout Rules

### General Rules
- All screens use Background Primary as the base
- Horizontal screen padding: 20px on both sides
- All interactive elements must be at minimum 48×48px tap targets
- Content scrolls; the primary CTA stays fixed at the bottom
- Use SafeArea-aware spacing at top and bottom

### Onboarding Screen Template

Every onboarding screen follows this structure (top to bottom):

1. **Top Nav Bar** — back button + progress indicator
2. **Scrollable Content Area**
   - Top spacing: LG (20px)
   - Section title (Headline Medium)
   - Section description (Body Medium, Text Secondary)
   - Gap: XL (24px)
   - Input fields, choice cards, or selectors
3. **Bottom CTA** — Primary Button pinned at bottom with Screen Padding on all sides

### Progressive Disclosure
- Only reveal fields that are relevant based on previous answers
- Example: show "Pain location" only if user selects "Yes" to current pain
- Example: show time inputs only if goal type is "Improve my time"
- Group related fields visually but never overwhelm with all fields visible at once

---

## Screen Inventory

### Auth Screens
1. **Splash** — logo, app name, loading state
2. **Welcome** — headline, value prop, Create Account (primary), Log In (secondary)
3. **Sign Up** — email, password, confirm password, create button, log in link
4. **Log In** — email, password, log in button, forgot password link, sign up link
5. **Forgot Password** — email field, reset button, confirmation message state

### Account Creation
6. **Account Setup** — units selector (segmented), gender selector, birthday picker, continue

### Onboarding Flow
7. **Onboarding Intro** — title, short explanation, progress context, start CTA
8. **Goal** — race type cards, race date toggle + picker, goal type cards, conditional time inputs
9. **Current Fitness** — experience level, weekly frequency, volume, longest run, yes/no questions, optional benchmark
10. **Schedule** — training days (chips), long run day, weekday/weekend availability, time of day
11. **Health & Injury** — pain toggle + location, injury history, health conditions, plan preference selector
12. **Training Preferences** — guidance mode, speed workouts, strength, surface, terrain, walk/run preference
13. **Watch & Device** — watch toggle, watch type, data usage, metrics, heart-rate zones, no-watch fallback
14. **Recovery & Lifestyle** — sleep, activity level, stress level, recovery feeling
15. **Motivation & Adherence** — reason for running, biggest obstacle, confidence, coaching tone
16. **Summary** — review cards with edit actions, "Build my plan" CTA
17. **Plan Generation** — loading animation, motivational message

---

## States to Design

For each screen and interactive component, design these states:

| State | When |
|-------|------|
| Default | Normal resting state |
| Selected | User has chosen this option |
| Disabled | Not yet available or conditions not met |
| Loading | Waiting for data or processing |
| Error | Validation failure or API error |
| Empty | No data to show yet |
| Success | Action completed successfully |

---

## Penpot File Organization

### Page 1 — Foundations
- Color tokens (all swatches with names)
- Typography scale (all styles with usage labels)
- Spacing scale (visual reference)
- Border radius tokens
- Icon set

### Page 2 — Components
- Buttons (primary, secondary — all states)
- Cards (choice, session, weekly calendar — all states)
- Chips (default, selected)
- Inputs (text field, date picker, time picker — all states)
- Selectors (segmented control — all states)
- Progress bar
- Top nav bar
- Bottom sheet

### Page 3 — Auth Screens
- Splash, Welcome, Sign Up, Log In, Forgot Password

### Page 4 — Account Creation + Onboarding
- Account Setup through Plan Generation (screens 6–17)

### Page 5 — States
- Loading, Empty, Error, Success patterns

---

## Design Checklist

Before marking any screen complete, verify:

- [ ] Dark background (Background Primary `#121212`)
- [ ] All colors reference the token system — no arbitrary values
- [ ] Typography uses only the defined scale
- [ ] Spacing uses only the defined tokens
- [ ] All tap targets are at minimum 48×48px
- [ ] Cards use rounded corners (LG radius)
- [ ] Clear visual hierarchy: title → description → content → CTA
- [ ] Primary CTA is bottom-aligned and full-width
- [ ] Progress indicator visible on onboarding screens
- [ ] Screen works for both short and long content (scroll behavior)
- [ ] No clutter — minimal and polished
- [ ] Copy works naturally in both Spanish and English
- [ ] All interactive components have default, selected, disabled, and error states designed
- [ ] Progressive disclosure is used where fields are conditional

---

## What NOT to Do

- Never use colors outside the token system
- Never use font sizes or weights outside the typography scale
- Never use spacing values outside the spacing scale
- Never design text that only works in one language
- Never make tap targets smaller than 48×48px
- Never show all conditional fields at once — use progressive disclosure
- Never split a single onboarding section across multiple screens unnecessarily
- Never add visual clutter — every element must earn its place
- Never design without all states (default, selected, disabled, error)
- Never block the design waiting for watch integration — design for no-watch first
