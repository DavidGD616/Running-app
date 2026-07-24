import 'package:flutter/material.dart';

import 'new_goal_review_screen.dart';

class NewGoalFitnessScreen extends StatelessWidget {
  const NewGoalFitnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewGoalReviewScreen(mode: NewGoalReviewMode.fitness);
  }
}
