import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';
import 'package:running_app/features/workout_guidance/presentation/workout_guidance_presenter.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_PresenterArtifacts> buildArtifacts(
    WidgetTester tester,
    TrainingSession session,
  ) async {
    late WorkoutGuidancePresenter presenter;
    late WorkoutGuidance guidance;
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            presenter = WorkoutGuidancePresenter(
              l10n: l10n,
              unitSystem: UnitSystem.km,
            );
            guidance = presenter.fromTrainingSession(session);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    return _PresenterArtifacts(
      presenter: presenter,
      guidance: guidance,
      l10n: l10n,
    );
  }

  testWidgets(
    'focus note is derived from session type, not session description',
    (tester) async {
      final session = TrainingSession(
        id: 'focus-from-type-not-description',
        date: DateTime(2026, 6, 11),
        type: SessionType.longRun,
        status: SessionStatus.completed,
        weekNumber: 4,
        distanceKm: 20,
        durationMinutes: 120,
        description:
            'This is an intentionally long description intended only for full session context in another part of the detail screen and should not be reused as coach focus text.',
        workoutTarget: const WorkoutTarget.effort(TargetZone.longRun),
      );

      final artifacts = await buildArtifacts(tester, session);

      expect(artifacts.guidance.focus, isNot(equals(session.description)));
      expect(
        artifacts.guidance.focus,
        equals(artifacts.l10n.workoutGuidanceFocusLongRun),
      );
      expect(
        artifacts.guidance.focus.length,
        lessThan(session.description!.length),
      );
    },
  );

  testWidgets(
    'repeat with targeted work child uses child target guidance and avoids fallback',
    (tester) async {
      final session = TrainingSession(
        id: 'repeat-work-child-guidance',
        date: DateTime(2026, 6, 11),
        type: SessionType.intervals,
        status: SessionStatus.completed,
        weekNumber: 4,
        workoutSteps: [
          WorkoutStep.repeat(
            repetitions: 4,
            target: null,
            steps: [
              WorkoutStep.work(
                distanceMeters: 400,
                target: const WorkoutTarget.pace(
                  TargetZone.interval,
                  paceMinSecPerKm: 345,
                  paceMaxSecPerKm: 355,
                ),
              ),
            ],
          ),
        ],
      );

      final artifacts = await buildArtifacts(tester, session);
      final phase = artifacts.guidance.phases.first;
      final pace = artifacts.presenter.targetGuidance(
        const WorkoutTarget.pace(TargetZone.interval),
      );

      expect(
        phase.headline,
        equals(artifacts.l10n.workoutGuidancePhaseControlledReps),
      );
      expect(
        phase.details,
        contains(artifacts.l10n.workoutGuidanceBeginnerCueFast),
      );
      expect(
        phase.details,
        contains(
          artifacts.l10n.workoutGuidanceFastPart(
            artifacts.l10n.workoutGuidanceZoneInterval,
          ),
        ),
      );
      expect(
        phase.details,
        contains(artifacts.l10n.workoutGuidancePaceDetail('5:45-5:55 min/km')),
      );
      expect(
        phase.details,
        isNot(contains(artifacts.l10n.workoutGuidanceDefaultHow)),
      );
      expect(pace, contains(artifacts.l10n.workoutGuidanceZoneInterval));
    },
  );

  testWidgets('repeat with targeted stride child uses child target guidance', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'repeat-stride-child-guidance',
      date: DateTime(2026, 6, 11),
      type: SessionType.hillRepeats,
      status: SessionStatus.completed,
      weekNumber: 4,
      workoutSteps: [
        WorkoutStep.repeat(
          repetitions: 6,
          target: null,
          steps: [
            WorkoutStep.stride(
              distanceMeters: 100,
              target: const WorkoutTarget.effort(
                TargetZone.interval,
                effortCue: 'Quick cadence',
              ),
            ),
          ],
        ),
      ],
    );

    final artifacts = await buildArtifacts(tester, session);
    final phase = artifacts.guidance.phases.first;

    expect(
      phase.headline,
      equals(artifacts.l10n.workoutGuidancePhaseFastRelaxed),
    );
    expect(phase.details, contains('Quick cadence'));
    expect(
      phase.details,
      isNot(contains(artifacts.l10n.workoutGuidanceDefaultHow)),
    );
  });

  testWidgets(
    'repeat without parent or child target still uses fallback guidance',
    (tester) async {
      final session = TrainingSession(
        id: 'repeat-untargeted-fallback',
        date: DateTime(2026, 6, 11),
        type: SessionType.fartlek,
        status: SessionStatus.completed,
        weekNumber: 4,
        workoutSteps: [
          WorkoutStep.repeat(
            repetitions: 3,
            target: null,
            steps: [
              const WorkoutStep.work(distanceMeters: 200),
              const WorkoutStep.recovery(duration: Duration(seconds: 90)),
            ],
          ),
        ],
      );

      final artifacts = await buildArtifacts(tester, session);

      expect(
        artifacts.guidance.phases.first.headline,
        equals(artifacts.l10n.workoutGuidancePhaseSmoothSurges),
      );
      expect(
        artifacts.guidance.phases.first.details,
        contains(artifacts.l10n.workoutGuidanceDefaultHow),
      );
    },
  );

  testWidgets(
    'repeat parent target preserves effort cue metadata over child guidance',
    (tester) async {
      final session = TrainingSession(
        id: 'repeat-parent-target-metadata',
        date: DateTime(2026, 6, 11),
        type: SessionType.intervals,
        status: SessionStatus.completed,
        weekNumber: 4,
        workoutSteps: [
          WorkoutStep.repeat(
            repetitions: 4,
            target: const WorkoutTarget.effort(
              TargetZone.interval,
              effortCue: 'Controlled hard efforts',
            ),
            steps: [
              WorkoutStep.work(
                distanceMeters: 400,
                target: const WorkoutTarget.pace(
                  TargetZone.threshold,
                  paceMinSecPerKm: 300,
                  paceMaxSecPerKm: 320,
                ),
              ),
            ],
          ),
        ],
      );

      final artifacts = await buildArtifacts(tester, session);
      final phase = artifacts.guidance.phases.first;

      expect(
        phase.headline,
        equals(artifacts.l10n.workoutGuidancePhaseControlledReps),
      );
      expect(phase.details, contains('Controlled hard efforts'));
      expect(
        phase.details,
        contains(
          artifacts.l10n.workoutGuidanceFastPart(
            artifacts.l10n.workoutGuidanceZoneInterval,
          ),
        ),
      );
      expect(phase.details.join('\n'), isNot(contains('5:00-5:20')));
      expect(
        phase.details,
        isNot(contains(artifacts.l10n.workoutGuidanceDefaultHow)),
      );
    },
  );

  testWidgets(
    'repeat with no parent/work/stride target uses recovery child guidance',
    (tester) async {
      final session = TrainingSession(
        id: 'repeat-recovery-child-guidance',
        date: DateTime(2026, 6, 11),
        type: SessionType.hillRepeats,
        status: SessionStatus.completed,
        weekNumber: 4,
        workoutSteps: [
          WorkoutStep.repeat(
            repetitions: 3,
            target: null,
            steps: [
              const WorkoutStep.work(distanceMeters: 200),
              WorkoutStep.recovery(
                duration: const Duration(seconds: 90),
                target: const WorkoutTarget.pace(
                  TargetZone.recovery,
                  paceMinSecPerKm: 420,
                  paceMaxSecPerKm: 480,
                ),
              ),
            ],
          ),
        ],
      );

      final artifacts = await buildArtifacts(tester, session);

      expect(
        artifacts.guidance.phases.first.details,
        contains(
          artifacts.l10n.workoutGuidanceRecoveryPart(
            artifacts.l10n.workoutGuidancePhaseRecovery,
          ),
        ),
      );
      expect(artifacts.guidance.phases.first.details, hasLength(1));
    },
  );

  testWidgets(
    'effort guide deduplicates repeated zones and keeps clear labels',
    (tester) async {
      final session = TrainingSession(
        id: 'dedupe-effort-guide',
        date: DateTime(2026, 6, 11),
        type: SessionType.fartlek,
        status: SessionStatus.completed,
        weekNumber: 4,
        workoutSteps: [
          WorkoutStep.warmUp(
            duration: const Duration(minutes: 10),
            target: const WorkoutTarget.effort(TargetZone.easy),
          ),
          WorkoutStep.repeat(
            repetitions: 4,
            steps: [
              WorkoutStep.work(
                distanceMeters: 300,
                target: const WorkoutTarget.effort(
                  TargetZone.steady,
                  effortCue: 'Smooth rhythm work',
                ),
              ),
              WorkoutStep.recovery(
                duration: const Duration(seconds: 60),
                target: const WorkoutTarget.effort(TargetZone.recovery),
              ),
            ],
          ),
          WorkoutStep.coolDown(
            duration: const Duration(minutes: 8),
            target: const WorkoutTarget.effort(TargetZone.easy),
          ),
        ],
      );

      final artifacts = await buildArtifacts(tester, session);

      expect(artifacts.guidance.effortGuideRows, hasLength(3));
      expect(
        artifacts.guidance.effortGuideRows.map((row) => row.label),
        orderedEquals([
          artifacts.l10n.workoutGuidanceEffortEasy,
          artifacts.l10n.workoutGuidanceEffortSteady,
          artifacts.l10n.workoutGuidanceEffortRecovery,
        ]),
      );
      expect(
        artifacts.guidance.effortGuideRows
            .singleWhere(
              (row) => row.label == artifacts.l10n.workoutGuidanceEffortSteady,
            )
            .cue,
        equals('Smooth rhythm work'),
      );
    },
  );

  testWidgets(
    'repeat phase titles come from session type labels for each speed-work session type',
    (tester) async {
      final cases = [
        (
          type: SessionType.intervals,
          label: (AppLocalizations l) => l.weeklyPlanSessionIntervals,
        ),
        (
          type: SessionType.fartlek,
          label: (AppLocalizations l) => l.sessionTypeFartlek,
        ),
        (
          type: SessionType.hillRepeats,
          label: (AppLocalizations l) => l.sessionTypeHillRepeats,
        ),
      ];

      for (final entry in cases) {
        final session = TrainingSession(
          id: 'repeat-${entry.type.name}-label',
          date: DateTime(2026, 6, 11),
          type: entry.type,
          status: SessionStatus.completed,
          weekNumber: 4,
          workoutSteps: [
            WorkoutStep.repeat(
              repetitions: 3,
              target: null,
              steps: const [WorkoutStep.work(duration: Duration(minutes: 30))],
            ),
          ],
        );

        final artifacts = await buildArtifacts(tester, session);
        expect(
          artifacts.guidance.phases.first.title,
          equals(entry.label(artifacts.l10n)),
        );
      }
    },
  );
}

class _PresenterArtifacts {
  _PresenterArtifacts({
    required this.presenter,
    required this.guidance,
    required this.l10n,
  });

  final WorkoutGuidancePresenter presenter;
  final WorkoutGuidance guidance;
  final AppLocalizations l10n;
}
