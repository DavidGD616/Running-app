// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RunFlow';

  @override
  String get languageCodeEN => 'EN';

  @override
  String get languageCodeES => 'ES';

  @override
  String get splashTagline => 'Train smarter. Run stronger.';

  @override
  String get welcomeTitle => 'Welcome to RunFlow';

  @override
  String get welcomeSubtitle =>
      'Your personal running coach. Build a plan tailored to your goals, fitness level, and schedule.';

  @override
  String get welcomeFeature1 => 'Personalized training plans';

  @override
  String get welcomeFeature2 => 'AI-powered progression';

  @override
  String get welcomeFeature3 => 'Flexible scheduling';

  @override
  String get createAccount => 'Create Account';

  @override
  String get logIn => 'Log In';

  @override
  String get logInTitle => 'Welcome back';

  @override
  String get logInSubtitle => 'Log in to continue your training.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign up';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpSubtitle =>
      'Start building your personalized training plan.';

  @override
  String get passwordHintSignUp => 'At least 6 characters';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get alreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get forgotPasswordTitle => 'Forgot password?';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we\'ll send you a reset link.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get backToLogIn => 'Back to Log In';

  @override
  String get accountSetupTitle => 'Account Setup';

  @override
  String get accountSetupSubtitle => 'Help us personalize your experience.';

  @override
  String get preferredUnits => 'Preferred Units';

  @override
  String get unitKm => 'km';

  @override
  String get unitMi => 'mi';

  @override
  String get genderLabel => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get dateOfBirthLabel => 'Date of Birth';

  @override
  String get dateOfBirthHint => 'DD / MM / YYYY';

  @override
  String get continueButton => 'Continue';

  @override
  String get homeReady => 'Your plan is ready!';

  @override
  String get homeComingSoon => 'Home screen coming soon.';

  @override
  String onboardingStep(int step, int total) {
    return '$step / $total';
  }

  @override
  String get onboardingIntroTitle => 'Let\'s build your plan';

  @override
  String get onboardingIntroSubtitle =>
      'Answer a few questions so we can create a training plan personalized to you. It takes about 3 minutes.';

  @override
  String get onboardingIntroFeature1 => 'Your race goal and timeline';

  @override
  String get onboardingIntroFeature2 => 'Fitness level and experience';

  @override
  String get onboardingIntroFeature3 => 'Schedule and preferences';

  @override
  String get onboardingIntroFooter =>
      '9 short sections · You can edit answers later';

  @override
  String get letsGo => 'Let\'s Go';

  @override
  String get goalTitle => 'What\'s your goal?';

  @override
  String get goalSubtitle =>
      'Tell us what you\'re training for and what outcome you want.';

  @override
  String get goalRaceLabel => 'Goal race';

  @override
  String get race5K => '5K';

  @override
  String get race10K => '10K';

  @override
  String get raceHalfMarathon => 'Half Marathon';

  @override
  String get raceMarathon => 'Marathon';

  @override
  String get raceOther => 'Other';

  @override
  String get raceCustomDistance => 'Custom distance';

  @override
  String get raceHasDateLabel => 'Do you have a race date?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get notSure => 'Not sure';

  @override
  String get raceDateLabel => 'Race date';

  @override
  String get tapToSetDate => 'DD / MM / YYYY';

  @override
  String get priorityLabel => 'What\'s your priority?';

  @override
  String get priorityJustFinish => 'Just finish';

  @override
  String get priorityFinishStrong => 'Finish feeling strong';

  @override
  String get priorityImproveTime => 'Improve my time';

  @override
  String get priorityConsistency => 'Build consistency';

  @override
  String get priorityGeneralFitness => 'General fitness';

  @override
  String get currentRaceTime => 'Current race time';

  @override
  String get targetRaceTime => 'Target race time';

  @override
  String get tapToSetTime => 'Tap to set time';

  @override
  String get timePickerHours => 'h';

  @override
  String get timePickerMinutes => 'min';

  @override
  String get timePickerSeconds => 'sec';

  @override
  String get confirm => 'Confirm';

  @override
  String get fitnessTitle => 'Current Fitness';

  @override
  String get fitnessSubtitle =>
      'Help us understand where you\'re starting from.';

  @override
  String get runningExperienceLabel => 'Running experience';

  @override
  String get experienceBrandNew => 'Brand new';

  @override
  String get experienceBrandNewSub => 'Never really run before';

  @override
  String get experienceBeginner => 'Beginner';

  @override
  String get experienceBeginnerSub => 'Some running, no consistent plan';

  @override
  String get experienceIntermediate => 'Intermediate';

  @override
  String get experienceIntermediateSub => 'Run regularly, some race experience';

  @override
  String get experienceExperienced => 'Experienced';

  @override
  String get experienceExperiencedSub => 'Structured training, multiple races';

  @override
  String get canRun10MinLabel =>
      'Can you currently run continuously for 10 minutes?';

  @override
  String get optionalBenchmark => 'Optional benchmark';

  @override
  String get optionalBadge => 'optional';

  @override
  String get currentRunDaysLabel => 'Current running days per week';

  @override
  String get weeklyVolumeLabel => 'Average weekly volume';

  @override
  String get longestRunLabel => 'Longest recent run';

  @override
  String get longestRunNone => 'I haven\'t done one';

  @override
  String get longestRunLessThan5km => 'Less than 5 km';

  @override
  String get longestRunLessThan3mi => 'Less than 3 mi';

  @override
  String get benchmarkKmRun => '1-km run time';

  @override
  String get benchmarkKmWalk => '1-km walk time';

  @override
  String get benchmarkMiRun => '1-mile run time';

  @override
  String get benchmarkMiWalk => '1-mile walk time';

  @override
  String get benchmark5K => '5K time';

  @override
  String get benchmark10K => '10K time';

  @override
  String get benchmarkHalfMarathon => 'Half marathon time';

  @override
  String get benchmarkSkipForNow => 'Skip for now';

  @override
  String benchmarkSelectedLabel(String benchmark) {
    return 'Your $benchmark';
  }

  @override
  String get canCompleteGoalLabel =>
      'Can you currently complete your goal distance?';

  @override
  String get raceDistanceBeforeLabel =>
      'Have you done this race distance before?';

  @override
  String get raceDistanceNever => 'Never';

  @override
  String get raceDistanceOnce => 'Once';

  @override
  String get raceDistance2to3 => '2-3';

  @override
  String get raceDistance4plus => '4+';

  @override
  String get yourBenchmarkTime => 'Your benchmark time';

  @override
  String get scheduleTitle => 'Your Schedule';

  @override
  String get scheduleSubtitle => 'Tell us when you can realistically train.';

  @override
  String get trainingDaysLabel => 'Training days per week';

  @override
  String get longRunDayLabel => 'Preferred long run day';

  @override
  String get longRunDayHelper => 'This is the anchor of your weekly plan';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get weekdayTimeLabel => 'Weekday time available';

  @override
  String get time20min => '20 min';

  @override
  String get time30min => '30 min';

  @override
  String get time45min => '45 min';

  @override
  String get time60min => '60 min';

  @override
  String get time75plusMin => '75+ min';

  @override
  String get weekendTimeLabel => 'Weekend time available';

  @override
  String get time90min => '90 min';

  @override
  String get time2plusHours => '2+ hours';

  @override
  String get hardDaysLabel => 'Days that are hard to train';

  @override
  String get selectAllThatApply => 'Select all that apply';

  @override
  String get timeOfDayLabel => 'Preferred time of day';

  @override
  String get timeOfDayEarlyMorning => 'Early morning';

  @override
  String get timeOfDayMorning => 'Morning';

  @override
  String get timeOfDayAfternoon => 'Afternoon';

  @override
  String get timeOfDayEvening => 'Evening';

  @override
  String get timeOfDayNoPreference => 'No preference';

  @override
  String get healthTitle => 'Health & Injury';

  @override
  String get healthSubtitle =>
      'Help us understand any limitations so your plan keeps you safe.';

  @override
  String get currentPainLabel => 'Current pain or injury?';

  @override
  String get painNo => 'No';

  @override
  String get painMild => 'Yes, mild';

  @override
  String get painModerate => 'Yes, moderate';

  @override
  String get painSevere => 'Yes, severe';

  @override
  String get recentInjuryLabel =>
      'Running-related injury in the last 12 months?';

  @override
  String get injuryNo => 'No';

  @override
  String get injuryOnce => 'Once';

  @override
  String get injuryMultiple => 'Multiple';

  @override
  String get healthConditionsLabel => 'Health conditions affecting exercise?';

  @override
  String get planPreferenceLabel => 'Plan preference';

  @override
  String get planSafest => 'Safest possible';

  @override
  String get planSafestSub => 'Prioritize injury prevention';

  @override
  String get planBalanced => 'Balanced';

  @override
  String get planBalancedSub => 'Mix of safety and progression';

  @override
  String get planPerformance => 'Performance-focused';

  @override
  String get planPerformanceSub => 'Push for results';

  @override
  String get trainingPrefsTitle => 'Training Preferences';

  @override
  String get trainingPrefsSubtitle => 'Customize how your plan is structured.';

  @override
  String get guidanceModeLabel => 'Preferred guidance mode';

  @override
  String get guidanceEffort => 'Effort';

  @override
  String get guidanceEffortSub => 'Train by perceived effort';

  @override
  String get guidancePace => 'Pace';

  @override
  String get guidancePaceSub => 'Train by pace targets';

  @override
  String get guidanceHeartRate => 'Heart rate';

  @override
  String get guidanceHeartRateSub => 'Train using HR zones';

  @override
  String get guidanceDecideForMe => 'Decide for me';

  @override
  String get guidanceDecideForMeSub => 'We\'ll pick the best approach';

  @override
  String get speedWorkoutsLabel => 'Speed workouts included?';

  @override
  String get onlyIfNeeded => 'Only if needed';

  @override
  String get strengthTrainingLabel => 'Strength training?';

  @override
  String get strength1DayWeek => '1 day/week';

  @override
  String get strength2DaysWeek => '2 days/week';

  @override
  String get strength3DaysWeek => '3 days/week';

  @override
  String get runSurfaceLabel => 'Where do you run most?';

  @override
  String get surfaceRoad => 'Road';

  @override
  String get surfaceTreadmill => 'Treadmill';

  @override
  String get surfaceTrack => 'Track';

  @override
  String get surfaceTrail => 'Trail';

  @override
  String get surfaceMixed => 'Mixed';

  @override
  String get terrainLabel => 'Terrain';

  @override
  String get terrainFlat => 'Flat';

  @override
  String get terrainSomeHills => 'Some hills';

  @override
  String get terrainHilly => 'Hilly';

  @override
  String get terrainMixed => 'Mixed';

  @override
  String get walkRunLabel => 'Walk/run intervals?';

  @override
  String get watchTitle => 'Watch & Device';

  @override
  String get watchSubtitle => 'Let us know what data sources are available.';

  @override
  String get usesWatchLabel => 'Do you use a watch or running device?';

  @override
  String get deviceLabel => 'Which device?';

  @override
  String get deviceGarmin => 'Garmin';

  @override
  String get deviceAppleWatch => 'Apple Watch';

  @override
  String get deviceCOROS => 'COROS';

  @override
  String get devicePolar => 'Polar';

  @override
  String get deviceSuunto => 'Suunto';

  @override
  String get deviceFitbit => 'Fitbit';

  @override
  String get deviceOther => 'Other';

  @override
  String get deviceDataUsageLabel => 'How should the app use your device data?';

  @override
  String get dataUsageImportAuto => 'Import runs automatically';

  @override
  String get dataUsageHROnly => 'Use heart rate only';

  @override
  String get dataUsagePaceDistance => 'Use pace and distance only';

  @override
  String get dataUsageAll => 'Use all available data';

  @override
  String get dataUsageNotSure => 'I\'m not sure';

  @override
  String get useWatchMetricsLabel => 'Use watch-based metrics?';

  @override
  String get hrOnly => 'HR only';

  @override
  String get metricsLabel => 'Which metrics?';

  @override
  String get metricHeartRate => 'Heart rate';

  @override
  String get metricHRZones => 'Heart rate zones';

  @override
  String get metricPace => 'Pace';

  @override
  String get metricDistance => 'Distance';

  @override
  String get metricCadence => 'Cadence';

  @override
  String get metricElevation => 'Elevation';

  @override
  String get metricTrainingLoad => 'Training load';

  @override
  String get metricRecoveryTime => 'Recovery time';

  @override
  String get metricNone => 'None';

  @override
  String get hrZonesLabel => 'Heart-rate-based training zones?';

  @override
  String get ifSupported => 'If supported';

  @override
  String get paceFromWatchLabel => 'Pace recommendations from watch?';

  @override
  String get autoAdjustLabel => 'Auto-adjust plan from watch data?';

  @override
  String get autoAdjustAuto => 'Auto';

  @override
  String get autoAdjustAskFirst => 'Ask first';

  @override
  String get noWatchInfo =>
      'No worries! The app works great without a watch. We\'ll guide your training differently.';

  @override
  String get noWatchGuidanceLabel => 'How should we guide your training?';

  @override
  String get noWatchEffortOnly => 'Effort only';

  @override
  String get noWatchEffortOnlySub => 'Train by how it feels';

  @override
  String get noWatchTimeBased => 'Time-based runs';

  @override
  String get noWatchTimeBasedSub => 'Run for set durations';

  @override
  String get noWatchBeginner => 'Simple beginner guidance';

  @override
  String get noWatchBeginnerSub => 'Step-by-step instructions';

  @override
  String get noWatchDecideForMe => 'Decide for me';

  @override
  String get noWatchDecideForMeSub => 'We\'ll pick what works best';

  @override
  String get recoveryTitle => 'Recovery & Lifestyle';

  @override
  String get recoverySubtitle =>
      'Quick questions to understand your recovery capacity.';

  @override
  String get sleepLabel => 'Average weekday sleep';

  @override
  String get sleepLessThan5h => '< 5h';

  @override
  String get sleep5to6h => '5–6h';

  @override
  String get sleep6to7h => '6–7h';

  @override
  String get sleep7to8h => '7–8h';

  @override
  String get sleep8plusH => '+8h';

  @override
  String get workLevelLabel => 'Work / activity level';

  @override
  String get workMostlyDesk => 'Mostly desk';

  @override
  String get workMostlyDeskSub => 'Sitting most of the day';

  @override
  String get workMixed => 'Mixed';

  @override
  String get workMixedSub => 'Some sitting, some moving';

  @override
  String get workPhysical => 'Physical job';

  @override
  String get workPhysicalSub => 'On your feet most of the day';

  @override
  String get stressLabel => 'Average stress level';

  @override
  String get stressLow => 'Low';

  @override
  String get stressModerate => 'Moderate';

  @override
  String get stressHigh => 'High';

  @override
  String get dayFeelingLabel => 'How do you feel day-to-day?';

  @override
  String get feelingFresh => 'Usually fresh';

  @override
  String get feelingSometimesTired => 'Sometimes tired';

  @override
  String get feelingOftenTired => 'Often tired';

  @override
  String get feelingAlwaysTired => 'Always tired';

  @override
  String get motivationTitle => 'Motivation & Adherence';

  @override
  String get motivationSubtitle =>
      'Help us understand what drives you and what might get in the way.';

  @override
  String get whyDoingThisLabel => 'Why are you doing this?';

  @override
  String get motivationPersonalChallenge => 'Personal challenge';

  @override
  String get motivationHealth => 'Health';

  @override
  String get motivationWeightLoss => 'Weight loss';

  @override
  String get motivationImprovePerformance => 'Improve performance';

  @override
  String get motivationRaceFriends => 'Race with friends/family';

  @override
  String get motivationDiscipline => 'Build discipline';

  @override
  String get motivationOther => 'Other';

  @override
  String get barriersLabel => 'What gets in the way of consistency?';

  @override
  String get barrierTime => 'Time';

  @override
  String get barrierMotivation => 'Motivation';

  @override
  String get barrierFatigue => 'Fatigue';

  @override
  String get barrierStress => 'Stress';

  @override
  String get barrierPain => 'Pain or soreness';

  @override
  String get barrierBoredom => 'Boredom';

  @override
  String get barrierDontKnowHow => 'I don\'t know how to train';

  @override
  String get barrierOther => 'Other';

  @override
  String get confidenceLabel => 'Confidence you\'ll stick with the plan';

  @override
  String get coachingToneLabel => 'Preferred coaching tone';

  @override
  String get toneSimple => 'Simple and direct';

  @override
  String get toneSimpleSub => 'Straight to the point';

  @override
  String get toneEncouraging => 'Encouraging';

  @override
  String get toneEncouragingSub => 'Supportive and positive';

  @override
  String get toneDetailed => 'Detailed and data-driven';

  @override
  String get toneDetailedSub => 'Numbers and explanations';

  @override
  String get toneStrict => 'Strict and performance-focused';

  @override
  String get toneStrictSub => 'Push me hard';

  @override
  String get summaryTitle => 'Your Plan Summary';

  @override
  String get summarySubtitle =>
      'Review your selections before we build your plan.';

  @override
  String get summaryGoalRace => 'Goal Race';

  @override
  String get summaryCurrentLevel => 'Current Level';

  @override
  String get summarySchedule => 'Schedule';

  @override
  String get summaryHealth => 'Health';

  @override
  String get summaryTraining => 'Training';

  @override
  String get summaryDevice => 'Device';

  @override
  String get summaryRecovery => 'Recovery';

  @override
  String get summaryMotivation => 'Motivation';

  @override
  String get summaryEverythingReady =>
      'Everything looks good. Ready to build your plan!';

  @override
  String get buildMyPlan => 'Build My Plan';

  @override
  String get editAnswers => 'Edit Answers';

  @override
  String summaryCanRun10Min(String yesNo) {
    return 'Can run 10 min: $yesNo';
  }

  @override
  String summaryFitnessDetail(String days, String volume) {
    return '$days days/wk · $volume weekly';
  }

  @override
  String summaryDaysPerWeek(String days) {
    return '$days days per week';
  }

  @override
  String summaryScheduleDetail(String longRun, String time, String weekday) {
    return 'Long run $longRun · $time · $weekday weekdays';
  }

  @override
  String get summaryNoPain => 'No current pain';

  @override
  String summaryWithPain(String level) {
    return 'Pain: $level';
  }

  @override
  String summaryPlanPref(String preference) {
    return '$preference plan preference';
  }

  @override
  String summaryGuidanceBased(String mode) {
    return '$mode-based guidance';
  }

  @override
  String summaryTrainingDetail(
    String speed,
    String strength,
    String surface,
    String terrain,
  ) {
    return 'Speed: $speed · Strength: $strength · $surface · $terrain';
  }

  @override
  String summaryDeviceConnected(String device) {
    return '$device connected';
  }

  @override
  String get summaryNoWatch => 'No watch';

  @override
  String summaryDeviceDetail(String usage, String hrZones, String auto) {
    return '$usage · HR zones: $hrZones · Auto-adjust: $auto';
  }

  @override
  String summarySleepHours(String hours) {
    return '$hours sleep';
  }

  @override
  String summaryRecoveryDetail(String work, String stress, String feeling) {
    return '$work · $stress stress · $feeling';
  }

  @override
  String summaryMotivationDetail(String tone, String score) {
    return '$tone tone · Confidence $score/10';
  }

  @override
  String get planGenerationTitle => 'Building Your Plan';

  @override
  String get planGenerationMsg1 => 'Analyzing your fitness profile...';

  @override
  String get planGenerationMsg2 => 'Calculating optimal training zones...';

  @override
  String get planGenerationMsg3 => 'Building your weekly structure...';

  @override
  String get planGenerationMsg4 => 'Personalizing session targets...';

  @override
  String get planGenerationMsg5 => 'Your plan is almost ready!';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String planReadyWeekPlanName(String weeks, String race) {
    return '$weeks-Week $race';
  }

  @override
  String get planReadyTitle => 'Your plan is ready';

  @override
  String get planReadyGoalLabel => 'Goal';

  @override
  String get planReadyScheduleLabel => 'Schedule';

  @override
  String get planReadyLongRunsLabel => 'Long Runs';

  @override
  String get planReadyGuidanceModeLabel => 'Guidance Mode';

  @override
  String planReadyGoalDescription(String race) {
    return 'Complete a $race';
  }

  @override
  String planReadyScheduleValue(String weeks, String runsPerWeek) {
    return '$weeks weeks • $runsPerWeek runs/week';
  }

  @override
  String get planReadyDescription =>
      'Tailored exactly to your fitness and schedule. We\'ll safely build your endurance so you reach the finish line feeling strong.';

  @override
  String get planReadyStartPlan => 'Start Plan';

  @override
  String get planReadyViewFullWeek => 'View Full Week';

  @override
  String get homeTitle => 'Today';

  @override
  String get homeSectionTodaysWorkout => 'Today\'s Workout';

  @override
  String get homeSectionUpNext => 'Up Next';

  @override
  String get homeSectionThisWeek => 'This Week';

  @override
  String get homeLogPastRun => 'Log Past Run';

  @override
  String get homeFullWeek => 'Full Week';

  @override
  String get workoutDurationLabel => 'Duration';

  @override
  String get workoutDistanceLabel => 'Distance';

  @override
  String get workoutTargetGuidanceLabel => 'Target Guidance';

  @override
  String get sessionDescEasyRun =>
      'Build your aerobic base for the Half Marathon. Keep the pace conversational throughout.';

  @override
  String sessionDescIntervals(
    int reps,
    String repDistance,
    int recoverySeconds,
  ) {
    return '$reps×$repDistance @ 5K pace. ${recoverySeconds}s recovery jog between each rep.';
  }

  @override
  String get sessionDescLongRun =>
      'Your key long run this week. Builds the endurance needed for your Half Marathon race day.';

  @override
  String get sessionDescRecoveryRun =>
      'Active recovery run to flush fatigue. Keep the effort very easy — slower than you think.';

  @override
  String get sessionDescTempoRun =>
      'Comfortably hard effort. You should be able to speak a few words but not hold a conversation.';

  @override
  String get workoutViewDetailsButton => 'View Workout';

  @override
  String get weekProgressRunsLabel => 'Runs';

  @override
  String get weekProgressVolumeLabel => 'Volume';

  @override
  String weekProgressFooter(String totalVolume, String unit) {
    return 'On track to hit $totalVolume $unit planned';
  }

  @override
  String get homeVolumeUnit => 'km';

  @override
  String get tabToday => 'Today';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabSettings => 'Settings';

  @override
  String weeklyPlanTitle(String week, String total) {
    return 'Week $week of $total';
  }

  @override
  String get weeklyPlanDistanceLabel => 'Distance';

  @override
  String get weeklyPlanTimeLabel => 'Time';

  @override
  String get weeklyPlanRunsLabel => 'Runs';

  @override
  String get weeklyPlanScheduleLabel => 'Schedule';

  @override
  String get weeklyPlanRestTitle => 'Rest';

  @override
  String get weeklyPlanRestSubtitle => 'Recovery day';

  @override
  String get weeklyPlanNowBadge => 'Now';

  @override
  String get weeklyPlanViewFullPlan => 'View Full Plan';

  @override
  String get weeklyPlanSessionEasyRun => 'Easy Run';

  @override
  String get weeklyPlanSessionIntervals => 'Intervals';

  @override
  String get weeklyPlanSessionLongRun => 'Long Run';

  @override
  String get weeklyPlanSessionRecoveryRun => 'Recovery Run';

  @override
  String get sessionTypeProgressionRun => 'Progression Run';

  @override
  String get sessionTypeHillRepeats => 'Hill Repeats';

  @override
  String get sessionTypeFartlek => 'Fartlek';

  @override
  String get sessionTypeThresholdRun => 'Threshold Run';

  @override
  String get sessionTypeRacePaceRun => 'Race Pace Run';

  @override
  String get sessionTypeCrossTraining => 'Cross Training';

  @override
  String get sessionTypeRestDay => 'Rest Day';

  @override
  String get sessionCategoryEndurance => 'Endurance';

  @override
  String get sessionCategorySpeedWork => 'Speed Work';

  @override
  String get sessionCategoryThreshold => 'Threshold';

  @override
  String get sessionCategoryRaceSpecific => 'Race Specific';

  @override
  String get sessionCategoryRecovery => 'Recovery';

  @override
  String get sessionCategoryRest => 'Rest';

  @override
  String get weeklyPlanDayMon => 'Mon';

  @override
  String get weeklyPlanDayTue => 'Tue';

  @override
  String get weeklyPlanDayWed => 'Wed';

  @override
  String get weeklyPlanDayThu => 'Thu';

  @override
  String get weeklyPlanDayFri => 'Fri';

  @override
  String get weeklyPlanDaySat => 'Sat';

  @override
  String get weeklyPlanDaySun => 'Sun';

  @override
  String get weeklyPlanDayToday => 'Today';

  @override
  String get progressTitle => 'Progress';

  @override
  String get progressSubtitle => 'You\'re building a solid habit. Keep it up.';

  @override
  String get progressStreakBannerSubtitle =>
      'You\'re staying consistently active.';

  @override
  String get progressWeeklyVolumeTitle => 'Weekly Volume';

  @override
  String get progressTrendingUp => 'Trending Up';

  @override
  String get progressRunsThisWeek => 'runs this week';

  @override
  String get progressDistanceLabel => 'Distance';

  @override
  String get progressTimeLabel => 'Time';

  @override
  String get progressStreakLabel => 'Streak';

  @override
  String get progressRunsLabel => 'Runs';

  @override
  String get progressRunsCompleted => 'Completed';

  @override
  String progressStreakSubtitle(String count) {
    return '$count weeks in a row';
  }

  @override
  String progressTrendUp(String percent) {
    return '▲ $percent% vs last mo';
  }

  @override
  String progressTrendDown(String percent) {
    return '▼ $percent% vs last mo';
  }

  @override
  String get progressWeeksUnit => 'wks';

  @override
  String get progressHourUnit => 'h';

  @override
  String get progressMinuteUnit => 'm';

  @override
  String get progressLongestRunTitle => 'Longest Run';

  @override
  String progressLongestRunImproved(String distance) {
    return '+$distance since start';
  }

  @override
  String get progressRecentSessionsTitle => 'Recent Sessions';

  @override
  String get progressViewAll => 'View All ›';

  @override
  String get progressSessionTempoRun => 'Tempo Run';

  @override
  String get sessionTypeTempoRun => 'Tempo Run';

  @override
  String get progressYesterday => 'Yesterday';

  @override
  String get progressTuesdayLabel => 'Tuesday';

  @override
  String get progressLastSunday => 'Last Sunday';

  @override
  String get progressWeekPrefix => 'W';

  @override
  String get progressCurrentWeek => 'CURRENT WEEK';

  @override
  String get progressElevationLabel => 'Elevation';

  @override
  String get progressSeeFullData => 'See Full Data';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPlanGoalsSection => 'Plan & Goals';

  @override
  String get settingsUpdatePlanInfo => 'Update Plan Info';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageValue => 'English';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsUnitsValue => 'Metric (km)';

  @override
  String get settingsAudioGuidance => 'Audio Guidance';

  @override
  String get settingsAudioValue => 'Minimal';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsValue => 'Enabled';

  @override
  String get settingsConnectedDevicesSection => 'Connected Devices';

  @override
  String get settingsGarminConnect => 'Garmin Connect';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsLogOut => 'Log Out';

  @override
  String get settingsVersion => 'RunFlow v1.0.0 (Build 42)';

  @override
  String get sessionDetailTitle => 'Workout';

  @override
  String get sessionDetailSessionType => 'Speed Work';

  @override
  String get sessionDetailTotalDistanceLabel => 'Total Distance';

  @override
  String get sessionDetailEstDurationLabel => 'Est. Duration';

  @override
  String get sessionDetailWorkoutStructure => 'Workout Structure';

  @override
  String get sessionDetailWarmUp => 'Warm-up';

  @override
  String get sessionDetailWarmUpNote => 'Easy pace, Zone 2';

  @override
  String get sessionDetailIntervals => 'Intervals';

  @override
  String get sessionDetailIntervalsNote => 'Hard effort, Zone 4';

  @override
  String get sessionDetailCoolDown => 'Cool-down';

  @override
  String get sessionDetailCoolDownDuration => '10 min';

  @override
  String get sessionDetailCoolDownNote => 'Easy pace or walk';

  @override
  String get sessionDetailStartWorkout => 'Start Workout';

  @override
  String sessionPhaseEasyRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunWarmNote =>
      'Brisk walk + light dynamic leg swings';

  @override
  String sessionPhaseEasyRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunMainNote =>
      'Conversational pace · Zone 2 · keep it relaxed';

  @override
  String sessionPhaseEasyRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunCoolNote =>
      'Walk it out · light static stretches';

  @override
  String sessionPhaseIntervalsWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseIntervalsWarmNote =>
      'Easy jog · strides at the end to prime the legs';

  @override
  String sessionPhaseIntervalsMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String sessionPhaseIntervalsMainNote(int reps, String repDistance) {
    return '$reps × $repDistance at hard effort · RPE 8–9';
  }

  @override
  String sessionPhaseIntervalsMainRecovery(int recoverySeconds) {
    return '$recoverySeconds s easy jog recovery between each rep';
  }

  @override
  String sessionPhaseIntervalsCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseIntervalsCoolNote =>
      'Easy jog → walk · full-body stretch';

  @override
  String sessionPhaseLongRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunWarmNote =>
      'Very easy jog · ease into the effort';

  @override
  String sessionPhaseLongRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunMainNote =>
      'Steady easy effort · Zone 2 · stay comfortable throughout';

  @override
  String sessionPhaseLongRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunCoolNote =>
      'Walk to finish · thorough stretch · refuel';

  @override
  String sessionPhaseRecoveryRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunWarmNote => 'Gentle walk to get moving';

  @override
  String sessionPhaseRecoveryRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunMainNote =>
      'Very easy conversational pace · no watch pressure';

  @override
  String sessionPhaseRecoveryRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunCoolNote => 'Walk · foam roll if available';

  @override
  String sessionPhaseTempoRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunWarmNote => 'Easy jog · build pace gradually';

  @override
  String sessionPhaseTempoRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunMainNote =>
      'Comfortably hard effort · Zone 3–4';

  @override
  String sessionPhaseTempoRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunCoolNote =>
      'Easy jog → walk · stretch thoroughly';

  @override
  String get logSessionTitle => 'Log Session';

  @override
  String get logSessionPlannedSession => 'Planned Session';

  @override
  String get logSessionSessionName => 'Morning Intervals';

  @override
  String get logSessionDurationLabel => 'DURATION';

  @override
  String get logSessionActiveTime => 'Active time';

  @override
  String get logSessionDistanceLabel => 'DISTANCE';

  @override
  String get logSessionMinUnit => 'min';

  @override
  String get logSessionKmUnit => 'km';

  @override
  String get logSessionPaceValue => '7:31 / km pace';

  @override
  String get logSessionHowDidItFeel => 'How did it feel?';

  @override
  String get logSessionEasy => 'Easy';

  @override
  String get logSessionModerate => 'Moderate';

  @override
  String get logSessionHard => 'Hard';

  @override
  String get logSessionVeryHard => 'Very Hard';

  @override
  String get logSessionNotes => 'Notes';

  @override
  String get logSessionOptional => '(Optional)';

  @override
  String get logSessionNotesHint => 'How did the run go?';

  @override
  String get logSessionSaveButton => 'Save Session';

  @override
  String get preRunTitle => 'Pre-run Check';

  @override
  String get preRunHeading => 'How are you feeling?';

  @override
  String get preRunSubtitle =>
      'Quick check to make sure today\'s interval session is still the right move.';

  @override
  String get preRunLegsQuestion => 'How do your legs feel today?';

  @override
  String get preRunFresh => 'Fresh';

  @override
  String get preRunNormal => 'Normal';

  @override
  String get preRunHeavy => 'Heavy';

  @override
  String get preRunPainQuestion => 'Any pain right now?';

  @override
  String get preRunNone => 'None';

  @override
  String get preRunMildDiscomfort => 'Mild discomfort';

  @override
  String get preRunModeratePain => 'Moderate pain';

  @override
  String get preRunSharpPain => 'Sharp pain';

  @override
  String get preRunSleepQuestion => 'How was your sleep?';

  @override
  String get preRunGreat => 'Great';

  @override
  String get preRunOkay => 'Okay';

  @override
  String get preRunPoor => 'Poor';

  @override
  String get preRunReadinessQuestion => 'Are you ready for this session?';

  @override
  String get preRunLetsGo => 'Let\'s go';

  @override
  String get preRunNotFullyReady => 'Not fully ready';

  @override
  String get preRunContinue => 'Continue';

  @override
  String get workoutOptionsTitle => 'Workout Options';

  @override
  String get workoutOptionsSkipWorkout => 'Skip Workout';

  @override
  String get workoutOptionsSkipWorkoutDescription =>
      'Removes this session from this week schedule';

  @override
  String get workoutOptionsRestoreWorkout => 'Restore Workout';

  @override
  String get workoutOptionsRestoreWorkoutDescription =>
      'Put this session back on the schedule';

  @override
  String get fullPlanTitle => 'Full Plan';

  @override
  String get fullPlanNote =>
      'This is your estimated full plan. It may change over time based on your progress and training adjustments.';

  @override
  String get fullPlanWeeksLabel => 'WEEKS';

  @override
  String get fullPlanDistanceLabel => 'DISTANCE';

  @override
  String get fullPlanRunsLabel => 'RUNS';

  @override
  String fullPlanWeekLabel(int number) {
    return 'Week $number';
  }

  @override
  String get fullPlanCurrentBadge => 'CURRENT';

  @override
  String get fullPlanCompletedBadge => 'DONE';

  @override
  String get fullPlanUpcomingBadge => 'UPCOMING';

  @override
  String get fullPlanScheduleLabel => 'SCHEDULE';
}
