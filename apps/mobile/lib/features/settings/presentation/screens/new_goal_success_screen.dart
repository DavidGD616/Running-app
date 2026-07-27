import 'package:flutter/material.dart';

import 'new_goal_review_screen.dart';

class NewGoalSuccessScreen extends StatelessWidget {
  const NewGoalSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewGoalReviewScreen(mode: NewGoalReviewMode.success);
  }
}
