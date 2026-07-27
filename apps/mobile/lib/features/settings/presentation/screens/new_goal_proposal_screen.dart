import 'package:flutter/material.dart';

import 'new_goal_review_screen.dart';

class NewGoalProposalScreen extends StatelessWidget {
  const NewGoalProposalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewGoalReviewScreen(mode: NewGoalReviewMode.proposal);
  }
}
