# Data Models

## Current state

The app now has a typed profile layer alongside the seeded training-plan domain:

- `TrainingPlan` remains the main source for planned workouts and most progress projections. It is still seeded locally in `training_plan_seed_data.dart`.
- `RunnerProfileDraft` is the typed, editable onboarding/settings draft state. It is owned by `onboardingProvider` and persisted locally with `SharedPreferences`.
- `RunnerProfile` is the durable completed-profile model. It is owned by `runnerProfileProvider`, persisted locally with `SharedPreferences`, and used for onboarding-complete gating.
- `UserPreferences` and `Locale` remain separate lightweight persisted settings.
- Progress-facing models such as `WeekProgress`, `RecentSession`, and `TrainingHistoryPoint` are still read models derived from `TrainingSession` seed data.

## State ownership

| Owner | State shape | Persistence | Notes |
| --- | --- | --- | --- |
| `trainingPlanProvider` | `TrainingPlan` | In memory only | Built from seed data. `skipSession` and `restoreSession` still affect only the current app run. |
| `weekProgressProvider` | `WeekProgress` | None | Computed from `TrainingPlan.currentWeekSessions`. |
| `completedSessionsProvider` | `List<TrainingSession>` | None | Filters completed non-rest sessions and sorts newest first. |
| `weeklyVolumeProvider` | `List<WeeklyVolumeData>` | None | Weekly chart projection derived from completed sessions. |
| `trainingHistorySeriesProvider` | `List<TrainingHistoryPoint>` | None | Bucketed chart projection keyed by `TrainingHistoryRange`. |
| `userStatsProvider` | `UserStats` | None | Current lightweight summary for streaks and completed run count. |
| `recentSessionsProvider` | `List<RecentSession>` | None | Top 3 completed sessions mapped for the progress screen. |
| `monthlyDistanceStatsProvider` | `MonthlyDistanceStats` | None | Current month vs previous month distance totals. |
| `monthlyTimeStatsProvider` | `MonthlyTimeStats` | None | Current month vs previous month duration totals. |
| `longestRunStatsProvider` | `LongestRunStats` | None | Best completed run distance and previous-best comparison. |
| `onboardingProvider` | `RunnerProfileDraft` | `SharedPreferences` | Persists the editable typed draft with versioned storage keys. |
| `runnerProfileProvider` | `RunnerProfile?` | `SharedPreferences` | Persists the completed typed profile and is the current profile source of truth. |
| `userPreferencesProvider` | `AsyncValue<UserPreferences>` | `SharedPreferences` | Persists unit system, short-distance unit, display name, gender, and DOB. |
| `localeProvider` | `AsyncValue<Locale>` | `SharedPreferences` | Persists selected locale with device-locale fallback on first launch. |
| `userProfileDisplayProvider` | `UserProfileDisplay` | None | Read-only plan metadata for profile/home UI. |

## Current typed profile domain

### Editable draft

`RunnerProfileDraft` is a composition of typed draft submodels:

- `GoalProfileDraft`
- `FitnessProfileDraft`
- `ScheduleProfileDraft`
- `HealthProfileDraft`
- `TrainingPreferencesProfileDraft`
- `DeviceProfileDraft`
- `RecoveryProfileDraft`
- `MotivationProfileDraft`

Each draft section stores canonical enums, numbers, booleans, dates, and durations. It does not store localized labels.

### Completed profile

`RunnerProfile` contains the finalized counterparts of the same sections plus profile metadata:

- `goal: GoalProfile`
- `fitness: FitnessProfile`
- `schedule: ScheduleProfile`
- `health: HealthProfile`
- `trainingPreferences: TrainingPreferencesProfile`
- `device: DeviceProfile`
- `recovery: RecoveryProfile`
- `motivation: MotivationProfile`
- `gender: ProfileGender?`
- `dateOfBirth: DateTime?`
- `schemaVersion: int`
- `updatedAt: DateTime`

The completed profile is created from the draft only when every required section can be promoted into a valid final model.

## Persistence boundaries

- `RunnerProfileDraft` is stored under the versioned key `runner_profile_draft_v1`.
- `RunnerProfile` is stored under the versioned key `runner_profile_v1`.
- Values are serialized as JSON with canonical enum keys such as `race_half_marathon`, `priority_improve_time`, and `day_sun`.
- Routing no longer treats `onboarding_completed` as sufficient by itself. The app only considers onboarding complete when a valid persisted `RunnerProfile` exists.
- The old `onboarding_completed` flag can still exist for compatibility, but it is no longer the source of truth for entering the main app.

## Other implemented model layers

### Training plan domain

| Model | Fields | Notes |
| --- | --- | --- |
| `TrainingPlan` | `id`, `raceType`, `totalWeeks`, `currentWeekNumber`, `sessions` | Also exposes computed getters `currentWeekSessions`, `todaySession`, `nextUpcomingSession`, and `allWeeks`. |
| `PlanWeek` | `weekNumber`, `sessions` | Grouping object returned by `TrainingPlan.allWeeks`. |
| `TrainingSession` | `id`, `date`, `type`, `status`, `weekNumber`, `distanceKm`, `durationMinutes`, `description`, `effort`, `phases`, `elevationGainMeters`, `intervalReps`, `intervalRepDistanceMeters`, `intervalRecoverySeconds`, `warmUpMinutes`, `coolDownMinutes` | Planned session entity; still mock-data driven. |
| `WorkoutPhase` | `type`, `iconAsset`, `title`, `duration`, `note`, `recoveryNote` | Used by detailed workout views. |
| `TrainingSessionEffort` | `easy`, `moderate`, `hard`, `veryEasy` | Optional effort metadata on a session. |
| `SessionType` | canonical session enum | Stored as domain values, not localized strings. |
| `SessionStatus` | `upcoming`, `today`, `completed`, `skipped` | Drives plan and progress UI state. |
| `WeekProgress` | `completedSessions`, `totalSessions`, `completedVolumeKm`, `totalVolumeKm`, `totalDurationMinutes` | Current-week completion summary. |

### Progress read models

| Model | Fields | Notes |
| --- | --- | --- |
| `RecentSession` | `id`, `date`, `distanceKm`, `durationMinutes`, `type` | Small recent-run projection. |
| `WeeklyVolumeData` | `distanceKm`, `timeHours`, `timeMinutes`, `elevationMeters`, `dateRange` | Weekly chart bucket model. |
| `TrainingHistoryPoint` | `startDate`, `endDate`, `label`, `axisLabel`, `distanceKm`, `durationMinutes`, `elevationMeters`, `isCurrent`, `isBest` | General-purpose chart point. |
| `UserStats` | `streakWeeks`, `totalRuns` | Compact progress summary. |
| `MonthlyDistanceStats` | `currentKm`, `previousKm`, `trendPct` | Month-over-month distance summary. |
| `MonthlyTimeStats` | `currentMinutes`, `previousMinutes`, `trendPct` | Month-over-month time summary. |
| `LongestRunStats` | `bestDistanceKm`, `previousBestKm` | Longest-run summary with computed deltas. |

## Target state

The next domain-model expansions planned after the typed profile foundation are:

1. `Goal` models that separate reusable goal state from onboarding/profile fields.
2. `ActivityRecord` models so logged workouts become durable completed activities independent of planned sessions.
3. Structured `WorkoutTarget` and workout-step models so intervals and targets are machine-readable.
4. `DeviceConnection` and related integration models so watch state lives outside onboarding answers.
5. Adaptation foundations such as session feedback and plan revision records.
