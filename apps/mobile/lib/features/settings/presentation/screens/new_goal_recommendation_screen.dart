import 'package:flutter/material.dart';

import 'new_goal_review_screen.dart';

class NewGoalRecommendationScreen extends StatelessWidget {
  const NewGoalRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewGoalReviewScreen(mode: NewGoalReviewMode.recommendation);
  }
}
