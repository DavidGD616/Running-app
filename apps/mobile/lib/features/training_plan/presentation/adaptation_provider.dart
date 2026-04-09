import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adaptation_repository.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';

class SessionFeedbackNotifier extends Notifier<List<SessionFeedback>> {
  @override
  List<SessionFeedback> build() {
    return ref.watch(adaptationRepositoryProvider).loadSessionFeedback();
  }

  Future<void> recordFeedback(SessionFeedback feedback) async {
    final next = [
      feedback,
      ...state.where((item) => item.id != feedback.id),
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    state = next;
    await ref.read(adaptationRepositoryProvider).saveSessionFeedback(next);
  }
}

class PlanAdjustmentsNotifier extends Notifier<List<PlanAdjustment>> {
  @override
  List<PlanAdjustment> build() {
    return ref.watch(adaptationRepositoryProvider).loadPlanAdjustments();
  }

  Future<void> recordAdjustment(PlanAdjustment adjustment) async {
    final next = [
      adjustment,
      ...state.where((item) => item.id != adjustment.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = next;
    await ref.read(adaptationRepositoryProvider).savePlanAdjustments(next);
  }
}

class PlanRevisionsNotifier extends Notifier<List<PlanRevision>> {
  @override
  List<PlanRevision> build() {
    return ref.watch(adaptationRepositoryProvider).loadPlanRevisions();
  }

  Future<void> recordRevision(PlanRevision revision) async {
    final next = [
      revision,
      ...state.where((item) => item.id != revision.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = next;
    await ref.read(adaptationRepositoryProvider).savePlanRevisions(next);
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
