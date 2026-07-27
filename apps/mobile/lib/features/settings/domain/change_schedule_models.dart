import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/domain/models/runner_profile.dart';
import '../../training_plan/domain/models/session_type.dart';
import '../../training_plan/domain/models/training_plan.dart';
import '../../training_plan/domain/models/training_session.dart';

/// A canonical, display-agnostic comparison of two plans for one ISO week.
///
/// The comparison intentionally contains no translated copy. Presentation code
/// maps [ChangeScheduleWeekSession.type] and the structural values to localized
/// labels at the UI boundary.
class ChangeScheduleWeekComparison {
  const ChangeScheduleWeekComparison({
    required this.weekStart,
    required this.currentWeek,
    required this.updatedWeek,
  });

  final DateTime weekStart;
  final List<ChangeScheduleWeekDay> currentWeek;
  final List<ChangeScheduleWeekDay> updatedWeek;

  /// Builds exactly seven Monday-to-Sunday day entries from the plan dates.
  ///
  /// [weekStart] must be the effective Monday supplied by the preview. This
  /// avoids silently comparing a different week if a malformed lifecycle
  /// payload contains a non-week-start date.
  factory ChangeScheduleWeekComparison.fromPlans({
    required TrainingPlan sourcePlan,
    required TrainingPlan candidatePlan,
    required DateTime weekStart,
  }) {
    final normalizedWeekStart = _changeScheduleDateOnly(weekStart);
    if (normalizedWeekStart.weekday != DateTime.monday) {
      throw const FormatException(
        'Change schedule effective week must begin on Monday.',
      );
    }

    return ChangeScheduleWeekComparison(
      weekStart: normalizedWeekStart,
      currentWeek: _changeScheduleWeekDays(sourcePlan, normalizedWeekStart),
      updatedWeek: _changeScheduleWeekDays(candidatePlan, normalizedWeekStart),
    );
  }
}

/// One fixed weekday in a [ChangeScheduleWeekComparison].
class ChangeScheduleWeekDay {
  const ChangeScheduleWeekDay({
    required this.weekday,
    required this.date,
    required this.sessions,
  });

  /// ISO weekday: Monday is 1 and Sunday is 7.
  final int weekday;
  final DateTime date;
  final List<ChangeScheduleWeekSession> sessions;

  bool get hasNoSession => sessions.isEmpty;

  bool get hasLongRun => sessions.any((session) => session.isLongRun);

  /// Favors an actionable workout for consumers that require one session.
  /// The schedule comparison itself renders every entry in [sessions].
  ChangeScheduleWeekSession? get primarySession {
    for (final session in sessions) {
      if (session.type != SessionType.restDay) return session;
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  bool get isExplicitRestDay =>
      primarySession?.type == SessionType.restDay && sessions.length == 1;
}

/// Stable source data for a plan session shown in a weekly comparison.
class ChangeScheduleWeekSession {
  const ChangeScheduleWeekSession({
    required this.id,
    required this.type,
    required this.isLongRun,
    this.summary,
    this.durationMinutes,
    this.distanceKm,
  });

  final String id;
  final SessionType type;

  /// Canonical plan text, if the source plan includes it. It is deliberately
  /// not a localized display label and should only be rendered after an
  /// explicit localization strategy exists for authored session summaries.
  final String? summary;
  final int? durationMinutes;
  final double? distanceKm;
  final bool isLongRun;

  factory ChangeScheduleWeekSession.fromTrainingSession(
    TrainingSession session,
  ) {
    final summary = session.description?.trim();
    return ChangeScheduleWeekSession(
      id: session.id,
      type: session.type,
      summary: summary == null || summary.isEmpty ? null : summary,
      durationMinutes: session.durationMinutes,
      distanceKm: session.distanceKm,
      isLongRun: session.type == SessionType.longRun,
    );
  }
}

List<ChangeScheduleWeekDay> _changeScheduleWeekDays(
  TrainingPlan plan,
  DateTime weekStart,
) {
  final weekEnd = weekStart.add(const Duration(days: 7));
  final sessionsByWeekday = <int, List<TrainingSession>>{};

  for (final session in plan.sessions) {
    final sessionDate = _changeScheduleDateOnly(session.date);
    if (sessionDate.isBefore(weekStart) || !sessionDate.isBefore(weekEnd)) {
      continue;
    }
    sessionsByWeekday.putIfAbsent(sessionDate.weekday, () => []).add(session);
  }

  return List<ChangeScheduleWeekDay>.generate(7, (index) {
    final weekday = index + 1;
    final sessions =
        List<TrainingSession>.from(sessionsByWeekday[weekday] ?? const [])
          ..sort((left, right) {
            final dateOrder = left.date.compareTo(right.date);
            return dateOrder == 0 ? left.id.compareTo(right.id) : dateOrder;
          });
    return ChangeScheduleWeekDay(
      weekday: weekday,
      date: weekStart.add(Duration(days: index)),
      sessions: sessions
          .map(ChangeScheduleWeekSession.fromTrainingSession)
          .toList(growable: false),
    );
  }, growable: false);
}

DateTime _changeScheduleDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

enum ChangeScheduleSameDayPreference {
  separateSessions('separate_sessions'),
  avoidSameDay('avoid_same_day');

  const ChangeScheduleSameDayPreference(this.key);
  final String key;

  static ChangeScheduleSameDayPreference parse(Object? value) {
    return switch (value) {
      'separate_sessions' => ChangeScheduleSameDayPreference.separateSessions,
      'avoid_same_day' => ChangeScheduleSameDayPreference.avoidSameDay,
      _ => ChangeScheduleSameDayPreference.separateSessions,
    };
  }

  static ChangeScheduleSameDayPreference? parseOrNull(Object? value) {
    for (final option in values) {
      if (option.key == value) return option;
    }
    return null;
  }
}

enum ChangeScheduleEffectiveWeek {
  current('current'),
  next('next');

  const ChangeScheduleEffectiveWeek(this.key);
  final String key;

  static ChangeScheduleEffectiveWeek parse(Object? value) {
    for (final option in values) {
      if (option.key == value) return option;
    }
    throw const FormatException('Invalid effective week value.');
  }

  /// Reads legacy local drafts that omitted the `effectiveWeek` field before
  /// the database column existed. Remote payloads must always use [parse] so
  /// schema regressions cannot silently become `current`.
  static ChangeScheduleEffectiveWeek parseLegacyLocalOrCurrent(Object? value) {
    if (value == null) return ChangeScheduleEffectiveWeek.current;
    return parse(value);
  }
}

typedef ChangeScheduleLocalDiscard = Future<bool> Function(String storageKey);

class ChangeScheduleAvailabilityDay {
  const ChangeScheduleAvailabilityDay({
    required this.day,
    required this.available,
    this.maxDurationMinutes,
  });

  final int day;
  final bool available;
  final int? maxDurationMinutes;

  Map<String, dynamic> toJson() => {
    'day': day,
    'available': available,
    if (maxDurationMinutes != null) 'max_duration_minutes': maxDurationMinutes,
  };

  static ChangeScheduleAvailabilityDay fromJson(Map<String, dynamic> json) {
    final rawDay = json['day'];
    if (rawDay is! int || rawDay < 1 || rawDay > 7) {
      throw const FormatException('Invalid day value.');
    }

    final rawAvailable = json['available'];
    if (rawAvailable is! bool) {
      throw const FormatException('Invalid day availability value.');
    }

    final rawMax = json['max_duration_minutes'];
    final maxMinutes = switch (rawMax) {
      null => null,
      int value when value > 0 => value,
      _ => throw const FormatException('Invalid max duration value.'),
    };

    return ChangeScheduleAvailabilityDay(
      day: rawDay,
      available: rawAvailable,
      maxDurationMinutes: maxMinutes,
    );
  }

  static ChangeScheduleAvailabilityDay fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid availability day.');
    }
    return fromJson(value.map((key, value) => MapEntry('$key', value)));
  }
}

class ChangeScheduleAvailability {
  const ChangeScheduleAvailability({
    required this.days,
    required this.targetRunningDays,
    required this.primaryLongRunWeekday,
    this.backupLongRunWeekday,
    required this.sameDayRunStrengthPreference,
  });

  final List<ChangeScheduleAvailabilityDay> days;
  final int targetRunningDays;
  final int primaryLongRunWeekday;
  final int? backupLongRunWeekday;
  final ChangeScheduleSameDayPreference sameDayRunStrengthPreference;

  List<int> get availableDays => [
    for (final day in days)
      if (day.available) day.day,
  ];

  bool get isValid {
    if (days.length != 7) return false;
    final seen = <int>{};
    for (final day in days) {
      if (!seen.add(day.day) || day.day < 1 || day.day > 7) return false;
      if (day.maxDurationMinutes != null && day.maxDurationMinutes! <= 0) {
        return false;
      }
    }

    if (targetRunningDays < 1 || targetRunningDays > 7) return false;
    if (!days.any((candidate) => candidate.day == primaryLongRunWeekday)) {
      return false;
    }
    if (availableDays.length != targetRunningDays) return false;
    if (!availableDays.contains(primaryLongRunWeekday)) return false;
    if (backupLongRunWeekday != null) {
      if (backupLongRunWeekday == primaryLongRunWeekday) return false;
      if (!availableDays.contains(backupLongRunWeekday!)) return false;
    }

    return true;
  }

  Map<String, dynamic> toJson() => {
    'days': days.map((day) => day.toJson()).toList(growable: false)
      ..sort((left, right) => (left['day'] as int) - (right['day'] as int)),
    'target_running_days': targetRunningDays,
    'primary_long_run_weekday': primaryLongRunWeekday,
    if (backupLongRunWeekday != null)
      'backup_long_run_weekday': backupLongRunWeekday,
    'same_day_run_strength_preference': sameDayRunStrengthPreference.key,
  };

  static ChangeScheduleAvailability fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Invalid availability.');
    }

    final map = json.map((key, value) => MapEntry('$key', value));
    final rawDays = map['days'];
    if (rawDays is! List) {
      throw const FormatException('Invalid availability days.');
    }

    final rawTarget = map['target_running_days'];
    if (rawTarget is! int || rawTarget < 1 || rawTarget > 7) {
      throw const FormatException('Invalid availability target_running_days.');
    }

    final rawPrimary = map['primary_long_run_weekday'];
    if (rawPrimary is! int || rawPrimary < 1 || rawPrimary > 7) {
      throw const FormatException(
        'Invalid availability primary_long_run_weekday.',
      );
    }

    final rawBackup = map['backup_long_run_weekday'];
    int? backup;
    if (rawBackup != null) {
      if (rawBackup is! int || rawBackup < 1 || rawBackup > 7) {
        throw const FormatException(
          'Invalid availability backup_long_run_weekday.',
        );
      }
      backup = rawBackup;
    }

    final rawPreference = ChangeScheduleSameDayPreference.parseOrNull(
      map['same_day_run_strength_preference'],
    );
    if (rawPreference == null) {
      throw const FormatException(
        'Invalid availability same_day_run_strength_preference.',
      );
    }

    final parsedDays = rawDays
        .map((value) => ChangeScheduleAvailabilityDay.fromMap(value))
        .toList(growable: false);

    final draft = ChangeScheduleAvailability(
      days: parsedDays,
      targetRunningDays: rawTarget,
      primaryLongRunWeekday: rawPrimary,
      backupLongRunWeekday: backup,
      sameDayRunStrengthPreference: rawPreference,
    );

    if (!draft.isValid) {
      throw const FormatException('Malformed availability payload.');
    }

    return draft;
  }

  ChangeScheduleAvailability withPrimaryLongRunDay(int longRunDay) => copyWith(
    primaryLongRunWeekday: longRunDay,
    targetRunningDays: targetRunningDays,
    days: [
      for (final existing in days)
        ChangeScheduleAvailabilityDay(
          day: existing.day,
          available: existing.day == longRunDay ? true : existing.available,
          maxDurationMinutes: existing.maxDurationMinutes,
        ),
    ],
  );

  ChangeScheduleAvailability copyWith({
    List<ChangeScheduleAvailabilityDay>? days,
    int? targetRunningDays,
    int? primaryLongRunWeekday,
    int? backupLongRunWeekday,
    bool clearBackupLongRunWeekday = false,
    ChangeScheduleSameDayPreference? sameDayRunStrengthPreference,
  }) {
    return ChangeScheduleAvailability(
      days: days ?? this.days,
      targetRunningDays: targetRunningDays ?? this.targetRunningDays,
      primaryLongRunWeekday:
          primaryLongRunWeekday ?? this.primaryLongRunWeekday,
      backupLongRunWeekday: clearBackupLongRunWeekday
          ? null
          : (backupLongRunWeekday ?? this.backupLongRunWeekday),
      sameDayRunStrengthPreference:
          sameDayRunStrengthPreference ?? this.sameDayRunStrengthPreference,
    );
  }
}

class ChangeScheduleDraft {
  const ChangeScheduleDraft({
    required this.availability,
    required this.effectiveWeek,
  });

  final ChangeScheduleAvailability availability;
  final ChangeScheduleEffectiveWeek effectiveWeek;

  bool get isValid => availability.isValid;

  DateTime effectiveFrom(DateTime now) {
    final monday = _toMonday(now);
    return effectiveWeek == ChangeScheduleEffectiveWeek.next
        ? monday.add(const Duration(days: 7))
        : monday;
  }

  Map<String, dynamic> previewPayload(DateTime localDate, DateTime now) {
    if (!isValid) {
      throw const FormatException('Invalid change schedule draft.');
    }

    return {
      'action': 'preview',
      'availability': availability.toJson(),
      'effectiveFrom': _dateOnly(effectiveFrom(now)),
      'localDate': _dateOnly(localDate),
    };
  }

  Map<String, dynamic> toJson() => {
    'availability': availability.toJson(),
    'effectiveWeek': effectiveWeek.key,
  };

  static ChangeScheduleDraft fromJson(
    Object? raw, {
    bool allowLegacyLocalEffectiveWeek = false,
  }) {
    if (raw is! Map) {
      throw const FormatException('Invalid change schedule draft.');
    }

    final map = raw.map((key, value) => MapEntry('$key', value));
    final availability = ChangeScheduleAvailability.fromJson(
      map['availability'],
    );
    final effectiveWeek = allowLegacyLocalEffectiveWeek
        ? ChangeScheduleEffectiveWeek.parseLegacyLocalOrCurrent(
            map['effectiveWeek'],
          )
        : ChangeScheduleEffectiveWeek.parse(map['effectiveWeek']);

    return ChangeScheduleDraft(
      availability: availability,
      effectiveWeek: effectiveWeek,
    );
  }

  ChangeScheduleDraft copyWith({
    ChangeScheduleAvailability? availability,
    ChangeScheduleEffectiveWeek? effectiveWeek,
  }) {
    return ChangeScheduleDraft(
      availability: availability ?? this.availability,
      effectiveWeek: effectiveWeek ?? this.effectiveWeek,
    );
  }

  static ChangeScheduleDraft inferFromLegacyProfileAndActivePlan({
    required RunnerProfile profile,
    required TrainingPlan activePlan,
    required DateTime clock,
  }) {
    final profileDays = _weekdaySetFromStrengthDays(profile.schedule.hardDays);
    final profileLongRun = _weekdayToInt(profile.schedule.longRunDay);
    final target = _clampPositive(profile.schedule.trainingDays, 1, 7);

    final weekdayTimes = _weekdayTimesFromSchedule(profile.schedule);
    final now = DateTime(clock.year, clock.month, clock.day);
    final upcomingRunDays = _runDaysFromPlan(activePlan, now);

    final selectedDays = <int>{profileLongRun};

    for (final day in upcomingRunDays) {
      if (selectedDays.length >= target) break;
      selectedDays.add(day);
    }

    for (final day in profileDays) {
      if (selectedDays.length >= target) break;
      selectedDays.add(day);
    }

    for (final day in _allWeekdaysInOrder()) {
      if (selectedDays.length >= target) break;
      selectedDays.add(day);
    }

    final selectedDaysSorted = selectedDays.toList(growable: false)..sort();

    final availabilityDays = _allWeekdaysInOrder()
        .map(
          (day) => ChangeScheduleAvailabilityDay(
            day: day,
            available: selectedDaysSorted.contains(day),
            maxDurationMinutes: selectedDaysSorted.contains(day)
                ? weekdayTimes[day]
                : null,
          ),
        )
        .toList(growable: false);

    final backup = selectedDaysSorted.length > 1
        ? selectedDaysSorted.firstWhere(
            (value) => value != profileLongRun,
            orElse: () => selectedDaysSorted.first,
          )
        : null;

    return ChangeScheduleDraft(
      availability: ChangeScheduleAvailability(
        days: availabilityDays,
        targetRunningDays: selectedDaysSorted.length,
        primaryLongRunWeekday: profileLongRun,
        backupLongRunWeekday: selectedDaysSorted.length > 1 ? backup : null,
        sameDayRunStrengthPreference:
            ChangeScheduleSameDayPreference.separateSessions,
      ),
      effectiveWeek: ChangeScheduleEffectiveWeek.current,
    );
  }
}

class StoredChangeScheduleDraft {
  const StoredChangeScheduleDraft({
    required this.draft,
    required this.sourcePlanId,
    required this.status,
    required this.revision,
    required this.updatedAt,
  });

  final ChangeScheduleDraft draft;
  final String sourcePlanId;
  final ChangeScheduleDraftStatus status;
  final int revision;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'data': draft.toJson(),
    'sourcePlanVersionId': sourcePlanId,
    'status': status.key,
    'revision': revision,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static StoredChangeScheduleDraft fromJson(
    Map<String, dynamic> json, {
    bool allowLegacyLocalEffectiveWeek = false,
  }) {
    final sourcePlanId = _requiredString(
      json['sourcePlanVersionId'],
      'sourcePlanVersionId',
    );
    final status = ChangeScheduleDraftStatus.parse(json['status']);
    final revision = json['revision'];
    if (revision is! int || revision <= 0) {
      throw const FormatException('Invalid stored draft revision.');
    }

    final rawUpdatedAt = json['updatedAt'];
    final updatedAt = rawUpdatedAt is String
        ? DateTime.tryParse(rawUpdatedAt)
        : null;
    if (updatedAt == null) {
      throw const FormatException('Invalid stored draft updatedAt.');
    }

    final draft = ChangeScheduleDraft.fromJson(
      json['data'],
      allowLegacyLocalEffectiveWeek: allowLegacyLocalEffectiveWeek,
    );
    return StoredChangeScheduleDraft(
      draft: draft,
      sourcePlanId: sourcePlanId,
      status: status,
      revision: revision,
      updatedAt: updatedAt,
    );
  }
}

abstract class ChangeScheduleDraftRemoteStore {
  Future<Map<String, dynamic>?> load();

  Future<DateTime?> save({
    required String sourcePlanId,
    required Map<String, dynamic> proposedAvailability,
    required String effectiveWeek,
    required ChangeScheduleDraftStatus status,
    required int revision,
  });

  Future<void> discard();
}

class _SupabaseChangeScheduleDraftRemoteStore
    implements ChangeScheduleDraftRemoteStore {
  _SupabaseChangeScheduleDraftRemoteStore({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  String _userId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw const FormatException('Missing authenticated user.');
    }
    return userId;
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final userId = _userId();
    final row = await _client
        .from('change_schedule_drafts')
        .select(
          'source_plan_version_id,proposed_availability,effective_week,status,revision,updated_at',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    return row.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<DateTime?> save({
    required String sourcePlanId,
    required Map<String, dynamic> proposedAvailability,
    required String effectiveWeek,
    required ChangeScheduleDraftStatus status,
    required int revision,
  }) async {
    final userId = _userId();
    final row = await _client
        .from('change_schedule_drafts')
        .upsert({
          'user_id': userId,
          'source_plan_version_id': sourcePlanId,
          'proposed_availability': proposedAvailability,
          'effective_week': effectiveWeek,
          'status': status.key,
          'revision': revision,
        }, onConflict: 'user_id')
        .select('updated_at')
        .maybeSingle();

    final updatedAt = row?['updated_at'];
    if (updatedAt is String) {
      return DateTime.tryParse(updatedAt);
    }

    return null;
  }

  @override
  Future<void> discard() async {
    await _client
        .from('change_schedule_drafts')
        .delete()
        .eq('user_id', _userId());
  }
}

enum ChangeScheduleDraftStatus {
  editing('editing'),
  assessmentPending('assessment_pending'),
  proposalReady('proposal_ready');

  const ChangeScheduleDraftStatus(this.key);
  final String key;

  static ChangeScheduleDraftStatus parse(Object? value) {
    for (final status in values) {
      if (status.key == value) return status;
    }
    throw const FormatException('Invalid change schedule draft status.');
  }
}

class ChangeScheduleDraftStore {
  ChangeScheduleDraftStore({
    required SharedPreferences preferences,
    required SupabaseClient? client,
    required String? userId,
    ChangeScheduleDraftRemoteStore? remoteStore,
    ChangeScheduleLocalDiscard? removeLocal,
  }) : _preferences = preferences,
       _remoteStore =
           remoteStore ??
           (client == null || userId == null
               ? null
               : _SupabaseChangeScheduleDraftRemoteStore(client: client)),
       _userId = userId,
       _removeLocal = removeLocal ?? preferences.remove,
       _storageKey = storageKeyForUser(userId);

  static const _storageKeyPrefix = 'change_schedule_draft_v1';

  static String storageKeyForUser(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '${_storageKeyPrefix}_guest';
    }
    return '${_storageKeyPrefix}_$normalized';
  }

  final SharedPreferences _preferences;
  final ChangeScheduleDraftRemoteStore? _remoteStore;
  final String? _userId;
  final ChangeScheduleLocalDiscard _removeLocal;
  final String _storageKey;

  String get storageKey => _storageKey;

  Future<StoredChangeScheduleDraft?> load() async {
    final local = _loadLocal();
    final userId = _userId;
    if (userId == null || _remoteStore == null) return local;

    try {
      final row = await _remoteStore.load();
      if (row == null) {
        await _removeLocalDraft();
        return null;
      }

      final remote = StoredChangeScheduleDraft.fromJson({
        'sourcePlanVersionId': row['source_plan_version_id'],
        'data': {
          'availability': row['proposed_availability'],
          'effectiveWeek': row['effective_week'],
        },
        'status': row['status'],
        'revision': row['revision'],
        'updatedAt': row['updated_at'],
      });

      try {
        await _saveLocal(remote);
      } catch (_) {
        // Keep remote authority even if local mirroring fails.
      }

      return remote;
    } on FormatException {
      rethrow;
    } catch (_) {
      // Local cache remains source of truth when remote is unavailable.
      return local;
    }
  }

  Future<void> save({
    required ChangeScheduleDraft draft,
    required String sourcePlanId,
    required ChangeScheduleDraftStatus status,
    required int revision,
    required DateTime updatedAt,
  }) async {
    final stored = StoredChangeScheduleDraft(
      draft: draft,
      sourcePlanId: sourcePlanId,
      status: status,
      revision: revision,
      updatedAt: updatedAt,
    );
    await _saveLocal(stored);

    final userId = _userId;
    if (userId == null || _remoteStore == null) return;

    try {
      final serverUpdatedAt = await _remoteStore.save(
        sourcePlanId: sourcePlanId,
        proposedAvailability: draft.availability.toJson(),
        effectiveWeek: draft.effectiveWeek.key,
        status: status,
        revision: revision,
      );
      if (serverUpdatedAt != null) {
        await _saveLocal(
          StoredChangeScheduleDraft(
            draft: draft,
            sourcePlanId: sourcePlanId,
            status: status,
            revision: revision,
            updatedAt: serverUpdatedAt,
          ),
        );
      }
    } catch (_) {
      // Local persistence remains available offline and must not block UX.
    }
  }

  Future<bool> discard() async {
    final userId = _userId;
    if (userId != null && _remoteStore != null) {
      try {
        await _remoteStore.discard();
      } catch (_) {
        return false;
      }
    }

    return _removeLocalDraft();
  }

  Future<bool> _removeLocalDraft() async {
    try {
      return await _removeLocal(_storageKey);
    } catch (_) {
      return false;
    }
  }

  StoredChangeScheduleDraft? _loadLocal() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return StoredChangeScheduleDraft.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
          allowLegacyLocalEffectiveWeek: true,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _saveLocal(StoredChangeScheduleDraft draft) async {
    await _preferences.setString(_storageKey, jsonEncode(draft.toJson()));
  }
}

/// Read-only lifecycle data owned by the server-side proposal and activation
/// tables. The mobile app uses this only to restore an already-authorized
/// lifecycle state after its auto-disposed provider is rebuilt.
class ChangeScheduleLifecycleData {
  const ChangeScheduleLifecycleData({
    this.pendingProposal,
    this.scheduledProposal,
    this.acceptedProposal,
    this.scheduledActivation,
  });

  final ChangeScheduleLifecycleProposal? pendingProposal;
  final ChangeScheduleLifecycleProposal? scheduledProposal;
  final ChangeScheduleLifecycleProposal? acceptedProposal;
  final ChangeScheduleLifecycleActivation? scheduledActivation;
}

sealed class ChangeScheduleLifecycleLoadResult {
  const ChangeScheduleLifecycleLoadResult();
}

class ChangeScheduleLifecycleAvailable
    extends ChangeScheduleLifecycleLoadResult {
  const ChangeScheduleLifecycleAvailable(this.data);

  final ChangeScheduleLifecycleData data;
}

/// The server lifecycle could not be reached safely (for example, no
/// configured/authenticated client or a transport outage). Callers may fall
/// back to the local editable draft, but must never use this for malformed
/// reachable rows.
class ChangeScheduleLifecycleUnavailable
    extends ChangeScheduleLifecycleLoadResult {
  const ChangeScheduleLifecycleUnavailable();
}

enum ChangeScheduleLifecycleProposalStatus {
  pending('pending'),
  scheduled('scheduled'),
  accepted('accepted');

  const ChangeScheduleLifecycleProposalStatus(this.key);
  final String key;

  static ChangeScheduleLifecycleProposalStatus parse(Object? value) {
    for (final status in values) {
      if (status.key == value) return status;
    }
    throw const FormatException('Invalid change schedule lifecycle status.');
  }
}

class ChangeScheduleLifecycleProposal {
  const ChangeScheduleLifecycleProposal({
    required this.id,
    required this.sourcePlanVersionId,
    required this.status,
    required this.proposedAvailability,
    required this.candidatePlan,
    required this.impacts,
    required this.warnings,
    required this.goalImpact,
    required this.effectiveFrom,
    required this.expiresAt,
    this.acceptedPlanVersionId,
    this.scheduledPlanVersionId,
    this.priorActivePlanVersionId,
    this.priorActiveAvailabilityVersionId,
    this.acceptedAvailabilityVersionId,
  });

  final String id;
  final String sourcePlanVersionId;
  final ChangeScheduleLifecycleProposalStatus status;
  final ChangeScheduleAvailability proposedAvailability;
  final Map<String, dynamic> candidatePlan;
  final List<dynamic> impacts;
  final List<String> warnings;
  final Map<String, dynamic> goalImpact;
  final DateTime effectiveFrom;
  final DateTime expiresAt;
  final String? acceptedPlanVersionId;
  final String? scheduledPlanVersionId;
  final String? priorActivePlanVersionId;
  final String? priorActiveAvailabilityVersionId;
  final String? acceptedAvailabilityVersionId;

  static ChangeScheduleLifecycleProposal fromDatabaseRow(Object? raw) {
    final row = _strictMap(raw);
    final status = ChangeScheduleLifecycleProposalStatus.parse(row['status']);
    final candidatePlan = _requiredMap(row['candidate_plan'], 'candidate_plan');
    if (TrainingPlan.fromJson(candidatePlan) == null) {
      throw const FormatException('Invalid lifecycle candidate plan.');
    }

    final impact = _requiredMap(row['impact'], 'impact');
    final rawImpacts = impact['impact'];
    if (rawImpacts is! List) {
      throw const FormatException('Invalid lifecycle impact list.');
    }
    final rawWarnings = impact['warnings'];
    if (rawWarnings is! List) {
      throw const FormatException('Invalid lifecycle warning list.');
    }
    final warnings = rawWarnings
        .map((warning) => _requiredString(warning, 'impact.warning'))
        .toList(growable: false);
    final goalImpact = _requiredMap(impact['goalImpact'], 'impact.goalImpact');

    final proposal = ChangeScheduleLifecycleProposal(
      id: _requiredString(row['id'], 'id'),
      sourcePlanVersionId: _requiredString(
        row['source_plan_version_id'],
        'source_plan_version_id',
      ),
      status: status,
      proposedAvailability: ChangeScheduleAvailability.fromJson(
        row['proposed_availability'],
      ),
      candidatePlan: candidatePlan,
      impacts: List<dynamic>.from(rawImpacts),
      warnings: warnings,
      goalImpact: goalImpact,
      effectiveFrom: _requiredDateOnly(row['effective_from'], 'effective_from'),
      expiresAt: _requiredDateTime(row['expires_at'], 'expires_at'),
      acceptedPlanVersionId: _optionalNullableString(
        row['accepted_plan_version_id'],
      ),
      scheduledPlanVersionId: _optionalNullableString(
        row['scheduled_plan_version_id'],
      ),
      priorActivePlanVersionId: _optionalNullableString(
        row['prior_active_plan_version_id'],
      ),
      priorActiveAvailabilityVersionId: _optionalNullableString(
        row['prior_active_availability_version_id'],
      ),
      acceptedAvailabilityVersionId: _optionalNullableString(
        row['accepted_availability_version_id'],
      ),
    );

    switch (proposal.status) {
      case ChangeScheduleLifecycleProposalStatus.pending:
        if (proposal.acceptedPlanVersionId != null ||
            proposal.scheduledPlanVersionId != null) {
          throw const FormatException('Invalid pending lifecycle lineage.');
        }
      case ChangeScheduleLifecycleProposalStatus.scheduled:
        if (proposal.scheduledPlanVersionId == null ||
            proposal.acceptedPlanVersionId != null) {
          throw const FormatException('Invalid scheduled lifecycle lineage.');
        }
      case ChangeScheduleLifecycleProposalStatus.accepted:
        if (proposal.acceptedPlanVersionId == null ||
            proposal.scheduledPlanVersionId != null) {
          throw const FormatException('Invalid accepted lifecycle lineage.');
        }
    }

    return proposal;
  }

  ChangeSchedulePreviewResponse toPreview({required DateTime asOfDate}) {
    return ChangeSchedulePreviewResponse(
      proposalId: id,
      sourcePlanVersionId: sourcePlanVersionId,
      effectiveFrom: effectiveFrom,
      asOfDate: asOfDate,
      expiresAt: expiresAt,
      candidatePlan: candidatePlan,
      impacts: impacts,
      warnings: warnings,
      goalImpact: goalImpact,
      proposedAvailability: proposedAvailability,
    );
  }

  ChangeScheduleDraft toDraft({
    required DateTime now,
    required bool requireCurrentOrNextWeek,
  }) {
    final currentMonday = _toMonday(now);
    final nextMonday = currentMonday.add(const Duration(days: 7));
    final effectiveWeek = _sameDate(effectiveFrom, nextMonday)
        ? ChangeScheduleEffectiveWeek.next
        : _sameDate(effectiveFrom, currentMonday)
        ? ChangeScheduleEffectiveWeek.current
        : requireCurrentOrNextWeek
        ? throw const FormatException('Unsupported lifecycle effective date.')
        : (effectiveFrom.isAfter(currentMonday)
              ? ChangeScheduleEffectiveWeek.next
              : ChangeScheduleEffectiveWeek.current);
    return ChangeScheduleDraft(
      availability: proposedAvailability,
      effectiveWeek: effectiveWeek,
    );
  }
}

class ChangeScheduleLifecycleActivation {
  const ChangeScheduleLifecycleActivation({
    required this.id,
    required this.sourcePlanVersionId,
    required this.queuedCandidatePlanVersionId,
    required this.availabilityVersionId,
    required this.effectiveFrom,
    required this.status,
    this.proposalId,
  });

  final String id;
  final String sourcePlanVersionId;
  final String queuedCandidatePlanVersionId;
  final String availabilityVersionId;
  final DateTime effectiveFrom;
  final String status;
  final String? proposalId;

  static ChangeScheduleLifecycleActivation fromDatabaseRow(Object? raw) {
    final row = _strictMap(raw);
    final status = _requiredString(row['status'], 'activation.status');
    if (status != 'scheduled') {
      throw const FormatException('Invalid activation lifecycle status.');
    }
    return ChangeScheduleLifecycleActivation(
      id: _requiredString(row['id'], 'activation.id'),
      sourcePlanVersionId: _requiredString(
        row['source_plan_version_id'],
        'activation.source_plan_version_id',
      ),
      queuedCandidatePlanVersionId: _requiredString(
        row['queued_candidate_plan_version_id'],
        'activation.queued_candidate_plan_version_id',
      ),
      availabilityVersionId: _requiredString(
        row['availability_version_id'],
        'activation.availability_version_id',
      ),
      effectiveFrom: _requiredDateOnly(
        row['effective_from'],
        'activation.effective_from',
      ),
      status: status,
      proposalId: _optionalNullableString(row['proposal_id']),
    );
  }

  bool matchesScheduledProposal(ChangeScheduleLifecycleProposal proposal) {
    if (proposal.status != ChangeScheduleLifecycleProposalStatus.scheduled) {
      return false;
    }
    return sourcePlanVersionId == proposal.sourcePlanVersionId &&
        queuedCandidatePlanVersionId == proposal.scheduledPlanVersionId &&
        _sameDate(effectiveFrom, proposal.effectiveFrom) &&
        (proposalId == proposal.id || proposalId == null);
  }

  ChangeScheduleScheduledResponse toScheduledResponse(
    ChangeScheduleLifecycleProposal proposal,
  ) {
    if (!matchesScheduledProposal(proposal)) {
      throw const FormatException('Scheduled lifecycle lineage mismatch.');
    }
    return ChangeScheduleScheduledResponse(
      proposalId: proposal.id,
      activationId: id,
      scheduledPlanVersionId: queuedCandidatePlanVersionId,
      scheduledAvailabilityVersionId: availabilityVersionId,
      activationStatus: status,
    );
  }
}

class ChangeSchedulePreviewResponse {
  ChangeSchedulePreviewResponse({
    required this.proposalId,
    required this.sourcePlanVersionId,
    required this.effectiveFrom,
    required this.asOfDate,
    required this.expiresAt,
    required this.candidatePlan,
    required this.impacts,
    required this.warnings,
    required this.goalImpact,
    required this.proposedAvailability,
  });

  final String proposalId;
  final String sourcePlanVersionId;
  final DateTime effectiveFrom;
  final DateTime asOfDate;
  final DateTime expiresAt;
  final Map<String, dynamic> candidatePlan;
  final List<dynamic> impacts;
  final List<String> warnings;
  final Map<String, dynamic> goalImpact;
  final ChangeScheduleAvailability proposedAvailability;

  static ChangeSchedulePreviewResponse fromJson(Object? raw) {
    final map = _strictMap(raw);

    final proposalId = _requiredString(map['proposalId'], 'proposalId');
    final sourcePlanVersionId = _requiredString(
      map['sourcePlanVersionId'],
      'sourcePlanVersionId',
    );
    final effectiveFrom = _requiredDateOnly(
      map['effectiveFrom'],
      'effectiveFrom',
    );
    final asOfDate = _requiredDateOnly(map['asOfDate'], 'asOfDate');
    final expiresAt = _requiredDateTime(map['expiresAt'], 'expiresAt');

    final candidatePlan = _requiredMap(map['candidatePlan'], 'candidatePlan');

    final rawImpacts = map['impacts'];
    if (rawImpacts is! List) {
      throw const FormatException('Invalid preview response: impacts.');
    }

    final rawWarnings = map['warnings'];
    if (rawWarnings is! List) {
      throw const FormatException('Invalid preview response: warnings.');
    }

    final warnings = rawWarnings
        .map((value) => _requiredString(value, 'warning'))
        .toList(growable: false);
    final goalImpact = _requiredMap(map['goalImpact'], 'goalImpact');
    final proposedAvailability = ChangeScheduleAvailability.fromJson(
      map['proposedAvailability'],
    );

    return ChangeSchedulePreviewResponse(
      proposalId: proposalId,
      sourcePlanVersionId: sourcePlanVersionId,
      effectiveFrom: effectiveFrom,
      asOfDate: asOfDate,
      expiresAt: expiresAt,
      candidatePlan: candidatePlan,
      impacts: rawImpacts,
      warnings: warnings,
      goalImpact: goalImpact,
      proposedAvailability: proposedAvailability,
    );
  }
}

class ChangeScheduleAcceptedResponse {
  const ChangeScheduleAcceptedResponse({
    required this.versionId,
    required this.plan,
    required this.priorActivePlanVersionId,
    required this.priorActiveAvailabilityVersionId,
    required this.acceptedAvailabilityVersionId,
  });

  final String versionId;
  final TrainingPlan plan;
  final String? priorActivePlanVersionId;
  final String? priorActiveAvailabilityVersionId;
  final String? acceptedAvailabilityVersionId;

  static ChangeScheduleAcceptedResponse fromJson(Object? raw) {
    final map = _strictMap(raw);
    final plan = TrainingPlan.fromJson(_requiredMap(map['plan'], 'plan'));
    if (plan == null) {
      throw const FormatException('Invalid change_schedule response: plan.');
    }
    return ChangeScheduleAcceptedResponse(
      versionId: _requiredString(map['versionId'], 'versionId'),
      plan: plan,
      priorActivePlanVersionId: _optionalNullableString(
        map['priorActivePlanVersionId'],
      ),
      priorActiveAvailabilityVersionId: _optionalNullableString(
        map['priorActiveAvailabilityVersionId'],
      ),
      acceptedAvailabilityVersionId: _optionalNullableString(
        map['acceptedAvailabilityVersionId'],
      ),
    );
  }
}

class ChangeScheduleScheduledResponse {
  const ChangeScheduleScheduledResponse({
    required this.proposalId,
    required this.activationId,
    required this.scheduledPlanVersionId,
    required this.scheduledAvailabilityVersionId,
    required this.activationStatus,
  });

  final String proposalId;
  final String activationId;
  final String scheduledPlanVersionId;
  final String scheduledAvailabilityVersionId;
  final String activationStatus;

  static ChangeScheduleScheduledResponse fromJson(Object? raw) {
    final map = _strictMap(raw);
    return ChangeScheduleScheduledResponse(
      proposalId: _requiredString(map['proposalId'], 'proposalId'),
      activationId: _requiredString(map['activationId'], 'activationId'),
      scheduledPlanVersionId: _requiredString(
        map['scheduledPlanVersionId'],
        'scheduledPlanVersionId',
      ),
      scheduledAvailabilityVersionId: _requiredString(
        map['scheduledAvailabilityVersionId'],
        'scheduledAvailabilityVersionId',
      ),
      activationStatus: _requiredString(
        map['activationStatus'],
        'activationStatus',
      ),
    );
  }
}

class ChangeScheduleCancelledResponse {
  const ChangeScheduleCancelledResponse({
    required this.proposalId,
    required this.proposalStatus,
    required this.activationId,
    required this.scheduledPlanVersionId,
  });

  final String proposalId;
  final String proposalStatus;
  final String? activationId;
  final String? scheduledPlanVersionId;

  static ChangeScheduleCancelledResponse fromJson(Object? raw) {
    final map = _strictMap(raw);
    return ChangeScheduleCancelledResponse(
      proposalId: _requiredString(map['proposalId'], 'proposalId'),
      proposalStatus: _requiredString(map['proposalStatus'], 'proposalStatus'),
      activationId: _optionalNullableString(map['activationId']),
      scheduledPlanVersionId: _optionalNullableString(
        map['scheduledPlanVersionId'],
      ),
    );
  }
}

class ChangeScheduleActivatedResponse {
  const ChangeScheduleActivatedResponse({
    required this.proposalId,
    required this.activationId,
    required this.proposalStatus,
    required this.acceptedPlanVersionId,
    required this.priorActivePlanVersionId,
    required this.priorActiveAvailabilityVersionId,
    required this.acceptedAvailabilityVersionId,
    required this.activationStatus,
    required this.plan,
  });

  final String? proposalId;
  final String activationId;
  final String? proposalStatus;
  final String? acceptedPlanVersionId;
  final String? priorActivePlanVersionId;
  final String? priorActiveAvailabilityVersionId;
  final String? acceptedAvailabilityVersionId;
  final String activationStatus;
  final Map<String, dynamic>? plan;

  static ChangeScheduleActivatedResponse fromJson(Object? raw) {
    final map = _strictMap(raw);

    return ChangeScheduleActivatedResponse(
      proposalId: _optionalNullableString(map['proposalId']),
      activationId: _requiredString(map['activationId'], 'activationId'),
      proposalStatus: _optionalNullableString(map['proposalStatus']),
      acceptedPlanVersionId: _optionalNullableString(
        map['acceptedPlanVersionId'],
      ),
      priorActivePlanVersionId: _optionalNullableString(
        map['priorActivePlanVersionId'],
      ),
      priorActiveAvailabilityVersionId: _optionalNullableString(
        map['priorActiveAvailabilityVersionId'],
      ),
      acceptedAvailabilityVersionId: _optionalNullableString(
        map['acceptedAvailabilityVersionId'],
      ),
      activationStatus: _requiredString(
        map['activationStatus'],
        'activationStatus',
      ),
      plan: _optionalMap(map['plan']),
    );
  }
}

class ChangeScheduleUndoneResponse {
  const ChangeScheduleUndoneResponse({
    required this.proposalId,
    required this.priorPlanVersionId,
    required this.priorAvailabilityVersionId,
    required this.restoredPlanVersionId,
    required this.restoredAvailabilityVersionId,
  });

  final String proposalId;

  /// The plan reactivated by the undo.
  final String priorPlanVersionId;

  /// The availability version reactivated by the undo.
  final String priorAvailabilityVersionId;

  /// The accepted plan just deactivated by the undo, when the server returns
  /// it. The legacy wire name is retained for compatibility with the Edge
  /// Function response.
  final String? restoredPlanVersionId;

  /// The accepted availability just cancelled by the undo, when the server
  /// returns it. The legacy wire name is retained for compatibility with the
  /// Edge Function response.
  final String? restoredAvailabilityVersionId;

  static ChangeScheduleUndoneResponse fromJson(Object? raw) {
    final map = _strictMap(raw);
    return ChangeScheduleUndoneResponse(
      proposalId: _requiredString(map['proposalId'], 'proposalId'),
      priorPlanVersionId: _requiredString(
        map['priorPlanVersionId'],
        'priorPlanVersionId',
      ),
      priorAvailabilityVersionId: _requiredString(
        map['priorAvailabilityVersionId'],
        'priorAvailabilityVersionId',
      ),
      restoredPlanVersionId: _optionalNullableString(
        map['restoredPlanVersionId'],
      ),
      restoredAvailabilityVersionId: _optionalNullableString(
        map['restoredAvailabilityVersionId'],
      ),
    );
  }
}

Map<String, dynamic> _strictMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  throw const FormatException('Expected an object.');
}

Map<String, dynamic>? _optionalMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  throw const FormatException('Invalid nullable map.');
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid change_schedule response: $field.');
  }
  return value;
}

String? _optionalNullableString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw const FormatException('Invalid nullable string.');
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  throw FormatException(
    'Invalid change_schedule response: $field must be map.',
  );
}

DateTime _requiredDateOnly(Object? value, String field) {
  if (value is! String) {
    throw FormatException('Invalid change_schedule response: $field.');
  }
  final parsed = _parseDateOnly(value);
  if (parsed == null) {
    throw FormatException('Invalid change_schedule response: $field.');
  }
  return parsed;
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('Invalid change_schedule response: $field.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid change_schedule response: $field.');
  }
  return parsed;
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _parseDateOnly(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;

  final parsed = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (parsed.year != int.parse(match.group(1)!) ||
      parsed.month != int.parse(match.group(2)!) ||
      parsed.day != int.parse(match.group(3)!)) {
    return null;
  }
  return parsed;
}

DateTime _toMonday(DateTime value) {
  final weekday = value.weekday;
  final shift = weekday - DateTime.monday;
  return DateTime(
    value.year,
    value.month,
    value.day,
  ).subtract(Duration(days: shift));
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

Set<int> _runDaysFromPlan(TrainingPlan plan, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final runDays = <int>{};
  for (final session in plan.sessions) {
    if (!session.isRunSession) continue;
    if (session.date.isBefore(today)) continue;
    runDays.add(session.date.weekday);
  }

  final ordered = runDays.toList(growable: false)
    ..sort(
      (left, right) => _distanceFrom(
        today.weekday,
        left,
      ).compareTo(_distanceFrom(today.weekday, right)),
    );

  return ordered.toSet();
}

int _distanceFrom(int nowWeekday, int candidateDay) {
  final delta = candidateDay - nowWeekday;
  return delta >= 0 ? delta : delta + 7;
}

Iterable<int> _allWeekdaysInOrder() => const [1, 2, 3, 4, 5, 6, 7];

Set<int> _weekdaySetFromStrengthDays(Set<WeekdayChoice> values) => {
  for (final value in values) _weekdayToInt(value),
};

int _weekdayToInt(WeekdayChoice value) => switch (value) {
  WeekdayChoice.monday => 1,
  WeekdayChoice.tuesday => 2,
  WeekdayChoice.wednesday => 3,
  WeekdayChoice.thursday => 4,
  WeekdayChoice.friday => 5,
  WeekdayChoice.saturday => 6,
  WeekdayChoice.sunday => 7,
};

Map<int, int> _weekdayTimesFromSchedule(ScheduleProfile schedule) {
  final weekdayMinutes = _minutesFromTimeSlot(schedule.weekdayTime);
  final weekendMinutes = _minutesFromTimeSlot(schedule.weekendTime);
  return {
    for (final day in _allWeekdaysInOrder())
      day: day <= 5 ? weekdayMinutes : weekendMinutes,
  };
}

int _minutesFromTimeSlot(TimeSlot value) => switch (value) {
  TimeSlot.min20 => 20,
  TimeSlot.min30 => 30,
  TimeSlot.min45 => 45,
  TimeSlot.min60 => 60,
  TimeSlot.min75Plus => 75,
  TimeSlot.min90 => 90,
  TimeSlot.hours2Plus => 120,
};

int _clampPositive(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
