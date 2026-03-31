```mermaid
classDiagram
class TrainingPlan {
  +String id
  +String name
  +String raceType
  +int totalWeeks
  +int currentWeekNumber
  +List<TrainingSession> sessions
}
class PlanWeek {
  +int weekNumber
  +List<TrainingSession> sessions
}
class TrainingSession {
  +String id
  +DateTime date
  +SessionType type
  +SessionStatus status
  +double? distanceKm
  +int? durationMinutes
  +List<WorkoutPhase> phases
}
class WorkoutPhase {
  +WorkoutPhaseType type
  +String title
  +String duration
  +String note
}
class SessionType
class SessionCategory
class SessionStatus
class WeekProgress {
  +int completedSessions
  +int totalSessions
  +double completedVolumeKm
  +double totalVolumeKm
  +int totalDurationMinutes
}
class RecentSession {
  +String title
  +String dateLabel
  +double distanceKm
  +int durationMinutes
}
class WeeklyVolumeData {
  +double distanceKm
  +int timeHours
  +int timeMinutes
  +int elevationMeters
  +String? dateRange
}
class UserStats {
  +int streakWeeks
  +double totalDistanceKm
  +int totalTimeMinutes
  +int totalRuns
  +String avgPacePerKm
  +double distanceTrendPct
  +double timeTrendPct
  +double longestRunKm
  +double longestRunImprovementKm
}
class UserPreferences {
  +UnitSystem unitSystem
  +String? gender
  +DateTime? dateOfBirth
}
class UnitSystem

TrainingPlan o-- TrainingSession : sessions
TrainingPlan --> PlanWeek : groupsInto
TrainingSession *-- WorkoutPhase : phases
TrainingSession --> SessionType
SessionType --> SessionCategory
TrainingSession --> SessionStatus
WeekProgress ..> TrainingSession : calcFrom
RecentSession --> SessionType
UserPreferences --> UnitSystem
UserStats ..> TrainingSession : streakWeeksFrom

```

### Derived data notes
- `WeekProgress` and `UserStats` never own raw session data; they recompute aggregates from the live `TrainingSession` list. The new streak logic walks Mondays backwards and only counts weeks containing a completed or today non-rest session, so gaps or rest-only weeks break the streak.
