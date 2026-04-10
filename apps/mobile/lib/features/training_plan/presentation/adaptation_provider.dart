import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adaptation_repository.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';

class SessionFeedbackNotifier extends Notifier<List<SessionFeedback>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  @override
  List<SessionFeedback> build() {
    final repository = ref.watch(adaptationRepositoryProvider);
    ref.watch(asyncAdaptationRepositoryProvider);
    unawaited(_hydrateFromRepository());
    return repository.loadSessionFeedback();
  }

  Future<void> recordFeedback(SessionFeedback feedback) async {
    final next = [
      feedback,
      ...state.where((item) => item.id != feedback.id),
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    state = next;
    await _asyncRepository.saveSessionFeedback(next);
  }

  Future<void> _hydrateFromRepository() async {
    final feedback = await _asyncRepository.loadSessionFeedback();
    if (ref.mounted) {
      state = feedback;
    }
  }
}

class PlanAdjustmentsNotifier extends Notifier<List<PlanAdjustment>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  @override
  List<PlanAdjustment> build() {
    final repository = ref.watch(adaptationRepositoryProvider);
    ref.watch(asyncAdaptationRepositoryProvider);
    unawaited(_hydrateFromRepository());
    return repository.loadPlanAdjustments();
  }

  Future<void> recordAdjustment(PlanAdjustment adjustment) async {
    final next = [
      adjustment,
      ...state.where((item) => item.id != adjustment.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = next;
    await _asyncRepository.savePlanAdjustments(next);
  }

  Future<void> _hydrateFromRepository() async {
    final adjustments = await _asyncRepository.loadPlanAdjustments();
    if (ref.mounted) {
      state = adjustments;
    }
  }
}

class PlanRevisionsNotifier extends Notifier<List<PlanRevision>> {
  AsyncAdaptationRepository get _asyncRepository =>
      ref.read(asyncAdaptationRepositoryProvider);

  @override
  List<PlanRevision> build() {
    final repository = ref.watch(adaptationRepositoryProvider);
    ref.watch(asyncAdaptationRepositoryProvider);
    unawaited(_hydrateFromRepository());
    return repository.loadPlanRevisions();
  }

  Future<void> recordRevision(PlanRevision revision) async {
    final next = [
      revision,
      ...state.where((item) => item.id != revision.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = next;
    await _asyncRepository.savePlanRevisions(next);
  }

  Future<void> _hydrateFromRepository() async {
    final revisions = await _asyncRepository.loadPlanRevisions();
    if (ref.mounted) {
      state = revisions;
    }
  }
}

final sessionFeedbackProvider =
    NotifierProvider<SessionFeedbackNotifier, List<SessionFeedback>>(
      SessionFeedbackNotifier.new,
    );

final planAdjustmentsProvider =
    NotifierProvider<PlanAdjustmentsNotifier, List<PlanAdjustment>>(
      PlanAdjustmentsNotifier.new,
    );

final planRevisionsProvider =
    NotifierProvider<PlanRevisionsNotifier, List<PlanRevision>>(
      PlanRevisionsNotifier.new,
    );
