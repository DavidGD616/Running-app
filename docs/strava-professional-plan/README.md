# Strava Professional Plan Spec

## Purpose

This spec defines the future Strava-driven plan creation experience for the running app. The goal is to stop using Strava mostly as a fitness label source and instead use Strava as a measured coaching evidence layer for professional plan generation.

The app is not live, so this work may replace the current onboarding and plan-generation contract instead of preserving the old flow.

## Product Goals

- Build plans from measured athlete history when Strava data is available.
- Show the user what the app learned from Strava before plan creation.
- Keep user-owned choices separate from Strava-derived coaching evidence.
- Generate more professional plans with personalized pace targets, race targets, leg-day constraints, and race guidance.
- Preserve safety limits from recent training load even when users choose aggressive goals.
- Support English and Spanish in the first implementation.

## Non-Goals

- Do not build a full strength-training app.
- Do not prescribe exact gym exercises in the first version.
- Do not make race day a startable training session.
- Do not create strength, lifting, mobility, or support sessions in v1.
- Do not persist raw Strava activity history long-term for this feature.
- Do not use HR as a primary workout target in the first version.
- Do not show non-running activity context on the Strava Analysis screen.
- Do not support plan-update/regeneration flows from settings in this scope.

## Current App Context

The current app already has a Strava feature under `apps/mobile/lib/features/strava/`.

Relevant current files:

- `apps/mobile/lib/features/strava/data/strava_service.dart`
- `apps/mobile/lib/features/strava/domain/athlete_summary.dart`
- `apps/mobile/lib/features/strava/domain/models/strava_athlete.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart`
- `apps/mobile/lib/features/onboarding/presentation/plan_generation_provider.dart`
- `apps/mobile/lib/features/profile/domain/models/runner_profile.dart`
- `supabase/functions/strava-sync/index.ts`
- `supabase/functions/generate-plan/index.ts`
- `supabase/functions/generate-plan/openai.ts`
- `supabase/functions/generate-plan/plan-rules.ts`

Current Strava summary derivation already calculates useful signals:

- Weekly volume.
- Volume trend.
- Acute/chronic ratio.
- Longest recent run.
- Typical easy and hard paces.
- Estimated threshold pace.
- Runs per week.
- Longest layoff.
- Active weeks.
- Data sufficiency.
- HR-zone availability.
- Benchmark projection.

The weak point is that the plan flow collapses this data too early into onboarding/profile fields. The future flow should keep a curated Strava coaching profile for analysis and plan generation.

## Target Onboarding Flow

The onboarding flow should be redesigned around professional plan creation:

1. Goal.
2. Fitness source.
3. Strava connect or manual fitness.
4. Strava Analysis.
5. Confirm or edit race target.
6. Schedule.
7. Health.
8. Strength constraints.
9. Preferences and intensity.
10. Generate plan.

The new onboarding should replace the old onboarding completely.

## Strava Data Confidence Paths

### Strong Data

When Strava has enough useful recent running data:

- Show full Strava Analysis.
- Show current training zones.
- Show primary and stretch race targets.
- Skip manual fitness questions.
- Continue to user-owned inputs: schedule, health, strength, preferences, intensity.

### Weak Data

When Strava has some useful data but not enough for full confidence:

- Show limited Strava Analysis.
- Explain what was found.
- Explain what is missing.
- Ask targeted manual fitness questions only for missing inputs.
- Use Strava as supporting evidence.

### No Useful Data

When Strava has no useful recent running data:

- Show that Strava connected successfully.
- Explain that there is not enough running history for plan creation.
- Continue with the full manual fitness flow.
- Keep Strava connected for future use.

## Strava Analysis Screen

The Strava Analysis screen is mandatory after connecting Strava. The user should not skip directly from Strava connection to plan generation.

The screen is read-only for analysis and evidence. Users can still edit user-owned inputs such as target, schedule, health, leg-day constraints, unit preference, and plan intensity.

### Required Sections

- Training Base.
- Endurance.
- Speed and pace zones.
- Terrain.
- Recovery and guardrails.
- Race target.
- Plan focus.

### Data Window

The screen must clearly show the analysis window.

Preferred copy shape:

```text
Based on your last 12 weeks of Strava running
```

Use these windows internally:

- Last 7 days: acute load.
- Last 28 days: current load.
- Last 8 to 12 weeks: readiness, consistency, volume trend, safety limits.
- Up to 6 months: historical best efforts and race evidence only.
- All-time stats: background experience only.

Recent 8 to 12 week data controls safety and workout pacing. Older efforts may inform confidence and stretch targets but must not override recent training readiness.

### Data Confidence

Show a subtle confidence label:

- High confidence.
- Medium confidence.
- Limited data.

Examples:

```text
High confidence
Based on 28 runs across the last 12 weeks.
```

```text
Limited data
Only 3 recent runs found, so pace targets will use more effort guidance.
```

### Evidence Display

Show dates for source evidence, but do not show Strava activity names by default.

Good:

```text
Longest recent run
May 30 - 22.0 km at 6:04/km - avg HR 158
```

Avoid by default:

```text
"Saturday long run by the beach" - May 30 - 22.0 km
```

### Plan Focus

The screen should end with a short coaching conclusion that explains what the generated plan will emphasize.

Examples:

```text
Your endurance base is ahead of your race-specific speed. The plan will keep long runs steady while adding threshold and 10K-pace work.
```

```text
Your recent training load is rising quickly. The plan will start controlled, then build once your weekly rhythm stabilizes.
```

The plan focus should come from deterministic coaching-profile logic where possible so the screen and generated plan stay aligned.

### Actions

For strong Strava data:

- Primary: Use Strava Analysis.
- Secondary: Use Manual Fitness Instead.
- Less prominent: Disconnect Strava.

For weak Strava data:

- Primary: Continue With Manual Details.
- Secondary: Disconnect Strava.

If data is strong, the screen should explain that Strava-based creation is recommended because it uses measured athlete history that manual onboarding cannot fully capture.

## User-Owned Inputs

These should stay user-owned and should not be overridden by Strava:

- Goal race distance.
- Race date, when applicable.
- Weekly training days.
- Preferred long-run day.
- Hard-to-train days.
- Health and injury constraints.
- Lower-body/leg-day constraints and same-day run/lift order.
- Unit preference.
- Plan intensity.
- Accepted primary race target.

Observed Strava run frequency may be shown in analysis, but not as a recommendation. Weekly training days are 100 percent user choice.

## Plan Intensity

Plan intensity should be a user choice:

- Conservative.
- Balanced.
- Ambitious.

The app should not recommend an intensity level. Intensity changes how the safe training range is used, but it must not bypass Strava-derived safety limits.

Example:

```text
User chooses the goal and intensity.
Strava controls safe progression.
```

## Race Targets

For race goals, Strava/manual evidence should produce a target-confirmation step after analysis/manual fitness. This step should show:

- Primary training target.
- Stretch target.
- Confidence.
- Evidence explanation.

Users may accept or adjust the primary target. If the user picks an aggressive target, the plan should respect the target but keep training load and progression within Strava-derived safety limits.

Goal onboarding should capture race distance and race date only. Do not store or transmit a goal priority field, current time, or target time from the goal step. Race target acceptance belongs only to the explicit target-confirmation step.

Preferred framing:

```text
Recommended training target
```

Avoid framing as a guaranteed prediction.

## Pace Targets

Plans should use structured personalized pace targets.

Internal storage:

- Store paces as seconds per kilometer.
- Render as `/mi` or `/km` based on unit preference.
- Pair every pace target with effort language.

Example internal data:

```json
{
  "zone": "threshold",
  "paceMinSecPerKm": 325,
  "paceMaxSecPerKm": 340,
  "effortCue": "comfortably hard"
}
```

Example display:

```text
8:43-9:07 /mi - comfortably hard
```

The Strava Analysis should show current training zones:

- Recovery.
- Easy.
- Long run.
- Steady.
- Tempo.
- Threshold.
- Race pace, when goal is known.
- Intervals.
- Strides.

Because onboarding selects the goal before Strava connection, the analysis can show both general pace zones and race-specific target pace.

## Live Pace Guidance

The professional plan should eventually use structured pace targets in the active run experience.

Rules:

- Use rolling pace, not instant GPS pace.
- Tolerate small deviations.
- Prompt only after sustained off-target running.
- Avoid repeated alerts.
- Be stricter for intervals and race-pace work than easy runs.
- For easy and long runs, prioritize "slow down" guidance over "speed up" guidance.
- Use calm coaching language.

Examples:

```text
On pace
8:57 /mi - target 8:50-9:05
```

```text
Ease up slightly
You have been faster than target for 45 seconds.
```

## Strength Constraints

Strength is constraint-only in v1. This is a running app, so strength should not appear as a session, support row, or prescribed workout.

Do include:

- Whether the user does lower-body/leg-day work.
- Selected leg days.
- Same-day run/lift order.
- Deterministic scheduling constraints so key runs and long runs are protected.

Do not include in the first version:

- Strength/support sessions.
- Exact exercises.
- Sets.
- Reps.
- Progressive gym programming.

Strength onboarding should ask:

- Whether the user does lower-body/leg-day work.
- Leg days.
- Same-day order preference:
  - Run first.
  - Lift first.
  - Separate sessions.
  - It depends.

The generated plan may use this information to avoid placing hard runs in bad positions around leg days. It should not show a separate strength item to the user.

## Terrain

The app should include terrain/elevation context.

Use Strava to analyze training terrain from recent runs. Ask optional race-course terrain when relevant:

- Flat.
- Rolling.
- Hilly.
- Not sure.

Use terrain to shape plan focus:

```text
Your recent training is mostly flat, but your race is rolling. The plan will include light hill work and effort-based pacing on climbs.
```

First version can use activity summary elevation. Detailed elevation streams are deferred.

## Heart Rate

Use HR behind the scenes for confidence and interpretation. Do not generate HR-targeted workouts in the first version.

HR may help determine:

- Whether easy runs look controlled.
- Whether pace estimates are reliable.
- Whether pace targets should be paired with stronger effort fallback.
- Whether endurance evidence is high or low confidence.

Primary workout targets remain pace plus effort.

## Activity Filtering

Runs drive the running plan.

Primary activity types:

- Run.
- TrailRun.
- VirtualRun.

Running activities control:

- Run volume.
- Run frequency.
- Longest run.
- Pace zones.
- Race target.
- Workout pacing.
- Progression.

Non-running activities may provide background context only:

- Walks.
- Hikes.
- Cycling.
- Swimming.
- Elliptical.
- Rowing.
- Strength.

Non-running activities should not appear on the Strava Analysis screen in the first version.

## Race Guidance

Generated plans should include race execution guidance for race goals. Race Day should appear as an info-only calendar item, not a startable run session.

Guidance should include:

- Race-day execution.
- Warmup.
- Primary target.
- Stretch target.
- Split or effort plan.
- When to press.
- What to avoid.
- Coaching notes.
- Sleep.
- Fueling.
- Hydration.
- Taper reminders.
- Weather/course notes where useful.

Plan Ready and Full Plan should stay compact. Race guidance should be accessible from the Race Day info item only. It should resemble the demo structure with sections like:

- Race-day execution.
- Coaching notes.

## Pace Zones After Generation

Pace-zone data remains available behind the scenes, but v1 should not show a full plan-level pace-zone table on Plan Ready or Full Plan.

Only the specific target pace/effort for the selected session should be shown in session detail and active-run surfaces.

Example:

```text
Threshold / Tempo
8:51-9:07 /mi - comfortably hard
```

Session detail should display structured targets for that session. Live "slow down" or "speed up" guidance belongs in the active run screen because session detail does not know the current pace.

## Localization

Spanish support is required in the first implementation.

Rules:

- App UI labels/buttons/static strings come from localization files.
- Structured values use canonical keys, not translated labels.
- AI-written coaching text is stored in the selected language at generation time.
- If a plan is generated in English, custom generated notes remain English.
- If a plan is generated in Spanish, custom generated notes remain Spanish.
- Dates, units, and paces must be formatted using locale and user unit preference.

## Storage

Use a hybrid storage model.

### Plan Version Snapshot

Store the full curated Strava coaching profile snapshot with the generated plan version.

Include privacy-safe provenance:

```json
{
  "source": "strava",
  "syncedAt": "2026-06-02T10:15:00Z",
  "dataWindow": "last12Weeks",
  "dataFromDate": "2026-03-10",
  "dataThroughDate": "2026-06-01",
  "activityCount": 34,
  "runActivityCount": 28,
  "confidence": "high"
}
```

### Runner Profile

Store only lightweight latest Strava-derived fitness/source info needed for onboarding state and "From Strava" behavior.

### Raw Activities

Do not persist raw Strava activities long-term for this feature unless a later analytics/sync feature requires it.

## Strava Data Strategy

### Phase 1

Use enriched activity summaries only.

Extend current sync normalization beyond the existing fields where available:

- Activity id.
- Distance.
- Moving time.
- Elapsed time.
- Average speed.
- Max speed.
- Average HR.
- Max HR, if available.
- Elevation gain.
- Start date.
- Type.
- Sport type.
- Perceived exertion, if available.
- Workout type, if available.

Do not use Strava activity names by default in the UI.

### Phase 2

Fetch detailed streams/splits only for selected important runs:

- Longest run.
- Best sustained effort.
- Recent race/time trial.
- Key quality workout.
- Aerobic HR marker.

Do not fetch streams for every activity.

## Plan Generation Contract

The current plan generation input should be replaced, not patched.

Future plan input should include:

- Goal profile.
- Strava coaching profile when available.
- Manual fitness profile when required.
- Accepted race target.
- Schedule preferences.
- Health constraints.
- Lower-body/leg-day strength constraints.
- Plan intensity.
- Unit preference.
- Locale.
- Race course terrain, when provided.

Future plan output should include:

- Plan metadata.
- Total weeks.
- Phases.
- Sessions.
- Structured workout targets.
- Structured pace ranges.
- Race guidance.
- Pace zones.
- Coaching profile snapshot.
- Generated locale.

Future plan output should not include `supportSessions` in v1. Legacy support-session JSON may be tolerated by readers, but it should not be generated or rendered.

## Open Decisions For Later

These decisions were intentionally left for later refinement:

- Exact shape of the new Dart and TypeScript schema.
- Exact thresholds for high, medium, and limited data confidence.
- Exact thresholds for load spike, layoff, low consistency, and pace uncertainty flags.
- Whether active run live pace guidance ships in the same milestone as plan generation.
