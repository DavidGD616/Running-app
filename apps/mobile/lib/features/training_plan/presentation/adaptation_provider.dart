import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adaptation_repository.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';

class SessionFeedbackNotifier extends AsyncNotifier<List<SessionFeedback>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  int _mutationEpoch = 0;

  @override
  Future<List<SessionFeedback>> build() async {
    ref.watch(asyncAdaptationRepositoryProvider);
    final buildEpoch = _mutationEpoch;
    final loaded = await _asyncRepository.loadSessionFeedback();
    if (!ref.mounted) return loaded;
    if (_mutationEpoch != buildEpoch) return state.value ?? loaded;
    return loaded;
  }

  Future<void> recordFeedback(SessionFeedback feedback) async {
    _mutationEpoch++;
    final current = _currentFeedback();
    final next = [feedback, ...current.where((item) => item.id != feedback.id)]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    state = AsyncData(next);
    await _asyncRepository.saveSessionFeedback(next);
  }

  List<SessionFeedback> _currentFeedback() {
    return state.maybeWhen(
      data: (feedback) => feedback,
      orElse: () => const [],
    );
  }
}

class PlanAdjustmentsNotifier extends AsyncNotifier<List<PlanAdjustment>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  int _mutationEpoch = 0;

  @override
  Future<List<PlanAdjustment>> build() async {
    ref.watch(asyncAdaptationRepositoryProvider);
    final buildEpoch = _mutationEpoch;
    final loaded = await _asyncRepository.loadPlanAdjustments();
    if (!ref.mounted) return loaded;
    if (_mutationEpoch != buildEpoch) return state.value ?? loaded;
    return loaded;
  }

  Future<void> recordAdjustment(PlanAdjustment adjustment) async {
    _mutationEpoch++;
    final current = _currentAdjustments();
    final next = [
      adjustment,
      ...current.where((item) => item.id != adjustment.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(next);
    await _asyncRepository.savePlanAdjustments(next);
  }

  List<PlanAdjustment> _currentAdjustments() {
    return state.maybeWhen(
      data: (adjustments) => adjustments,
      orElse: () => const [],
    );
  }
}

class PlanRevisionsNotifier extends AsyncNotifier<List<PlanRevision>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  int _mutationEpoch = 0;

  @override
  Future<List<PlanRevision>> build() async {
    ref.watch(asyncAdaptationRepositoryProvider);
    final buildEpoch = _mutationEpoch;
    final loaded = await _asyncRepository.loadPlanRevisions();
    if (!ref.mounted) return loaded;
    if (_mutationEpoch != buildEpoch) return state.value ?? loaded;
    return loaded;
  }

  Future<void> recordRevision(PlanRevision revision) async {
    _mutationEpoch++;
    final current = _currentRevisions();
    final next = [revision, ...current.where((item) => item.id != revision.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(next);
    await _asyncRepository.savePlanRevisions(next);
  }

  List<PlanRevision> _currentRevisions() {
    return state.maybeWhen(
      data: (revisions) => revisions,
      orElse: () => const [],
    );
  }
}

final sessionFeedbackProvider =
    AsyncNotifierProvider<SessionFeedbackNotifier, List<SessionFeedback>>(
      SessionFeedbackNotifier.new,
    );

final planAdjustmentsProvider =
    AsyncNotifierProvider<PlanAdjustmentsNotifier, List<PlanAdjustment>>(
      PlanAdjustmentsNotifier.new,
    );

final planRevisionsProvider =
    AsyncNotifierProvider<PlanRevisionsNotifier, List<PlanRevision>>(
      PlanRevisionsNotifier.new,
    );
