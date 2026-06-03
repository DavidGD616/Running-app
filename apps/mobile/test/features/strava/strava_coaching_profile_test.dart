import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';

void main() {
  group('Strava coaching profile models', () {
    test('strong profile round-trip preserves all model data', () {
      final profile = _strongProfile();

      final restored = StravaCoachingProfile.fromJson(profile.toJson());

      expect(restored.toJson(), profile.toJson());
      expect(restored.dataConfidence, StravaDataConfidence.high);
      expect(restored.trainingBase, hasLength(2));
      expect(restored.raceTargets, hasLength(1));
      expect(restored.paceZones.threshold.paceMinSecPerKm, 255);
    });

    test('weak profile round-trip remains parseable and stable', () {
      final profile = _weakProfile();

      final restored = StravaCoachingProfile.fromJson(profile.toJson());

      expect(restored.toJson(), profile.toJson());
      expect(restored.dataConfidence, StravaDataConfidence.medium);
      expect(restored.recoveryGuardrails, hasLength(2));
      expect(
        restored.raceTargets.single.confidence,
        StravaDataConfidence.medium,
      );
    });

    test('no-useful-data profile round-trip keeps limited confidence', () {
      final profile = _noUsefulDataProfile();

      final restored = StravaCoachingProfile.fromJson(profile.toJson());

      expect(restored.toJson(), profile.toJson());
      expect(restored.dataConfidence, StravaDataConfidence.limited);
      expect(restored.trainingBase, isEmpty);
      expect(restored.endurance, isEmpty);
      expect(restored.speedMarkers, isEmpty);
      expect(restored.raceTargets, isEmpty);
      expect(restored.terrain, StravaTerrainProfile.notSure);
      expect(restored.paceZones.recovery.paceMinSecPerKm, isNull);
      expect(restored.paceZones.recovery.paceMaxSecPerKm, isNull);
    });

    test('individual model round-trips are stable', () {
      final provenance = _provenance(
        confidence: StravaDataConfidence.high,
        activityCount: 64,
        runActivityCount: 58,
      );
      final evidence = StravaEvidencePoint(
        metric: 'training_base_weekly_km',
        date: DateTime.utc(2026, 5, 31),
        value: 47.5,
        unit: 'km_per_week',
      );
      final paceZone = const StravaPaceZone(
        paceMinSecPerKm: 300,
        paceMaxSecPerKm: 345,
      );
      final paceZones = const StravaPaceZones(
        recovery: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
        easy: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 370),
        longRun: StravaPaceZone(paceMinSecPerKm: 325, paceMaxSecPerKm: 360),
        steady: StravaPaceZone(paceMinSecPerKm: 305, paceMaxSecPerKm: 330),
        tempo: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 300),
        threshold: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 270),
        racePace: StravaPaceZone(paceMinSecPerKm: 252, paceMaxSecPerKm: 262),
        intervals: StravaPaceZone(paceMinSecPerKm: 225, paceMaxSecPerKm: 250),
        strides: StravaPaceZone(paceMinSecPerKm: 190, paceMaxSecPerKm: 220),
      );
      final guardrail = const StravaGuardrail(
        priority: 1,
        category: 'recovery_sleep',
        message: 'Keep easy days truly easy this week.',
      );
      final raceTarget = StravaRaceTargetEstimate(
        distanceKm: 10,
        primaryTime: const Duration(minutes: 47, seconds: 10),
        stretchTime: const Duration(minutes: 45, seconds: 30),
        confidence: StravaDataConfidence.high,
        evidence: [evidence],
      );
      final focus = const StravaPlanFocus(
        category: 'focus_endurance',
        summary: 'Build durable aerobic volume before sharpening.',
      );

      expect(
        StravaAnalysisProvenance.fromJson(provenance.toJson()).toJson(),
        provenance.toJson(),
      );
      expect(
        StravaEvidencePoint.fromJson(evidence.toJson()).toJson(),
        evidence.toJson(),
      );
      expect(
        StravaPaceZone.fromJson(paceZone.toJson()).toJson(),
        paceZone.toJson(),
      );
      expect(
        StravaPaceZones.fromJson(paceZones.toJson()).toJson(),
        paceZones.toJson(),
      );
      expect(
        StravaGuardrail.fromJson(guardrail.toJson()).toJson(),
        guardrail.toJson(),
      );
      expect(
        StravaRaceTargetEstimate.fromJson(raceTarget.toJson()).toJson(),
        raceTarget.toJson(),
      );
      expect(StravaPlanFocus.fromJson(focus.toJson()).toJson(), focus.toJson());
    });

    test('invalid coaching profile json throws FormatException', () {
      final json = _strongProfile().toJson()..remove('provenance');

      expect(
        () => StravaCoachingProfile.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid confidence key throws FormatException', () {
      final json = _strongProfile().toJson();
      json['dataConfidence'] = 'unsupported';

      expect(
        () => StravaCoachingProfile.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid pace zone bounds throw FormatException', () {
      expect(
        () => StravaPaceZone.fromJson({
          'paceMinSecPerKm': 320,
          'paceMaxSecPerKm': 300,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid provenance activity counts throw FormatException', () {
      expect(
        () => StravaAnalysisProvenance.fromJson({
          'source': 'strava_sync',
          'syncedAt': DateTime.utc(2026, 6, 1).toIso8601String(),
          'dataWindow': 'last12Weeks',
          'dataFromDate': DateTime.utc(2026, 3, 9).toIso8601String(),
          'dataThroughDate': DateTime.utc(2026, 6, 1).toIso8601String(),
          'activityCount': 4,
          'runActivityCount': 5,
          'confidence': StravaDataConfidence.high.key,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid race target distance throws FormatException', () {
      expect(
        () => StravaRaceTargetEstimate.fromJson({
          'distanceKm': 0,
          'primaryTimeSec': 3600,
          'confidence': StravaDataConfidence.medium.key,
          'evidence': [
            {
              'metric': 'speed_marker_5k_pace',
              'date': DateTime.utc(2026, 5, 30).toIso8601String(),
              'value': 280,
              'unit': 'sec_per_km',
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('StravaGuardrail priority 4 throws FormatException', () {
      expect(
        () => StravaGuardrail.fromJson({
          'priority': 4,
          'category': 'recovery',
          'message': 'message',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('StravaGuardrail priority -1 throws FormatException', () {
      expect(
        () => StravaGuardrail.fromJson({
          'priority': -1,
          'category': 'recovery',
          'message': 'message',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('unrecognized terrain key throws FormatException', () {
      final json = _strongProfile().toJson()..['terrain'] = 'mountainous';

      expect(
        () => StravaCoachingProfile.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('StravaGuardrail priority double is accepted and coerced', () {
      final parsed = StravaGuardrail.fromJson({
        'priority': 2.0,
        'category': 'recovery',
        'message': 'message',
      });

      expect(parsed.priority, 2);
    });
  });
}

StravaCoachingProfile _strongProfile() {
  final evidence1 = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 5, 25),
    value: 48.2,
    unit: 'km_per_week',
  );
  final evidence2 = StravaEvidencePoint(
    metric: 'endurance_long_run_km',
    date: DateTime.utc(2026, 5, 30),
    value: 24,
    unit: 'km',
  );
  final evidence3 = StravaEvidencePoint(
    metric: 'speed_marker_5k_pace',
    date: DateTime.utc(2026, 5, 29),
    value: 256,
    unit: 'sec_per_km',
  );

  return StravaCoachingProfile(
    provenance: _provenance(
      confidence: StravaDataConfidence.high,
      activityCount: 64,
      runActivityCount: 58,
    ),
    dataConfidence: StravaDataConfidence.high,
    trainingBase: [evidence1, evidence2],
    endurance: [evidence2],
    speedMarkers: [evidence3],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
      easy: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 370),
      longRun: StravaPaceZone(paceMinSecPerKm: 325, paceMaxSecPerKm: 360),
      steady: StravaPaceZone(paceMinSecPerKm: 305, paceMaxSecPerKm: 330),
      tempo: StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 300),
      threshold: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 270),
      racePace: StravaPaceZone(paceMinSecPerKm: 252, paceMaxSecPerKm: 262),
      intervals: StravaPaceZone(paceMinSecPerKm: 225, paceMaxSecPerKm: 250),
      strides: StravaPaceZone(paceMinSecPerKm: 190, paceMaxSecPerKm: 220),
    ),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 0,
        category: 'recovery_load',
        message: 'Avoid stacking intensity on back-to-back days.',
      ),
    ],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 10,
        primaryTime: const Duration(minutes: 46, seconds: 40),
        stretchTime: const Duration(minutes: 45, seconds: 10),
        confidence: StravaDataConfidence.high,
        evidence: [evidence3],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_threshold_and_endurance',
      summary: 'Build threshold durability while preserving long-run quality.',
    ),
  );
}

StravaCoachingProfile _weakProfile() {
  final baseEvidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 5, 28),
    value: 24,
    unit: 'km_per_week',
  );
  final speedEvidence = StravaEvidencePoint(
    metric: 'speed_marker_10k_pace',
    date: DateTime.utc(2026, 5, 21),
    value: 310,
    unit: 'sec_per_km',
  );

  return StravaCoachingProfile(
    provenance: _provenance(
      confidence: StravaDataConfidence.medium,
      activityCount: 21,
      runActivityCount: 16,
    ),
    dataConfidence: StravaDataConfidence.medium,
    trainingBase: [baseEvidence],
    endurance: [
      StravaEvidencePoint(
        metric: 'endurance_long_run_km',
        date: DateTime.utc(2026, 5, 24),
        value: 12,
        unit: 'km',
      ),
    ],
    speedMarkers: [speedEvidence],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 390, paceMaxSecPerKm: 450),
      easy: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 400),
      longRun: StravaPaceZone(paceMinSecPerKm: 355, paceMaxSecPerKm: 390),
      steady: StravaPaceZone(paceMinSecPerKm: 335, paceMaxSecPerKm: 360),
      tempo: StravaPaceZone(paceMinSecPerKm: 315, paceMaxSecPerKm: 335),
      threshold: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 315),
      racePace: StravaPaceZone(paceMinSecPerKm: 295, paceMaxSecPerKm: 308),
      intervals: StravaPaceZone(paceMinSecPerKm: 275, paceMaxSecPerKm: 295),
      strides: StravaPaceZone(paceMinSecPerKm: 230, paceMaxSecPerKm: 270),
    ),
    terrain: StravaTerrainProfile.flat,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 1,
        category: 'recovery_sleep',
        message: 'Prioritize sleep before hard workouts.',
      ),
      StravaGuardrail(
        priority: 2,
        category: 'recovery_spacing',
        message: 'Keep one full easy day between intense sessions.',
      ),
    ],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 5,
        primaryTime: const Duration(minutes: 27, seconds: 0),
        confidence: StravaDataConfidence.medium,
        evidence: [speedEvidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_consistency',
      summary: 'Build consistency and avoid spikes in training load.',
    ),
  );
}

StravaCoachingProfile _noUsefulDataProfile() {
  return StravaCoachingProfile(
    provenance: _provenance(
      confidence: StravaDataConfidence.limited,
      activityCount: 2,
      runActivityCount: 1,
    ),
    dataConfidence: StravaDataConfidence.limited,
    trainingBase: const [],
    endurance: const [],
    speedMarkers: const [],
    paceZones: const StravaPaceZones.empty(),
    terrain: StravaTerrainProfile.notSure,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 0,
        category: 'recovery_readiness',
        message: 'Not enough data yet. Start with easy, low-volume running.',
      ),
    ],
    raceTargets: const [],
    planFocus: const StravaPlanFocus(
      category: 'focus_data_collection',
      summary: 'Complete more runs to improve personalization confidence.',
    ),
  );
}

StravaAnalysisProvenance _provenance({
  required StravaDataConfidence confidence,
  required int activityCount,
  required int runActivityCount,
}) {
  return StravaAnalysisProvenance(
    source: 'strava_sync',
    syncedAt: DateTime.utc(2026, 6, 1, 12),
    dataWindow: 'last12Weeks',
    dataFromDate: DateTime.utc(2026, 3, 9),
    dataThroughDate: DateTime.utc(2026, 6, 1),
    activityCount: activityCount,
    runActivityCount: runActivityCount,
    confidence: confidence,
  );
}
