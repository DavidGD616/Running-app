import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'RunFlow'**
  String get appTitle;

  /// Short English language code shown on the toggle
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageCodeEN;

  /// Short Spanish language code shown on the toggle
  ///
  /// In en, this message translates to:
  /// **'ES'**
  String get languageCodeES;

  /// Tagline shown on the splash screen
  ///
  /// In en, this message translates to:
  /// **'Train smarter. Run stronger.'**
  String get splashTagline;

  /// Main heading on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to RunFlow'**
  String get welcomeTitle;

  /// Subtitle on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Your personal running coach. Build a plan tailored to your goals, fitness level, and schedule.'**
  String get welcomeSubtitle;

  /// First feature bullet on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Personalized training plans'**
  String get welcomeFeature1;

  /// Second feature bullet on welcome screen
  ///
  /// In en, this message translates to:
  /// **'AI-powered progression'**
  String get welcomeFeature2;

  /// Third feature bullet on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Flexible scheduling'**
  String get welcomeFeature3;

  /// Primary CTA button on welcome screen and sign up screen
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Log in button label
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Heading on the log in screen
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get logInTitle;

  /// Subtitle on the log in screen
  ///
  /// In en, this message translates to:
  /// **'Log in to continue your training.'**
  String get logInSubtitle;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Email field placeholder
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Forgot password link on log in screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Log in screen link to sign up
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get dontHaveAccount;

  /// Heading on the sign up screen
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// Subtitle on the sign up screen
  ///
  /// In en, this message translates to:
  /// **'Start building your personalized training plan.'**
  String get signUpSubtitle;

  /// Password hint on sign up screen
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordHintSignUp;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// Confirm password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// Sign up screen link to log in
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get alreadyHaveAccount;

  /// Heading on the forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordTitle;

  /// Subtitle on the forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset link.'**
  String get forgotPasswordSubtitle;

  /// Button on forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Back link on forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Back to Log In'**
  String get backToLogIn;

  /// Heading on the account setup screen
  ///
  /// In en, this message translates to:
  /// **'Account Setup'**
  String get accountSetupTitle;

  /// Subtitle on the account setup screen
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your experience.'**
  String get accountSetupSubtitle;

  /// Section label on account setup screen
  ///
  /// In en, this message translates to:
  /// **'Preferred Units'**
  String get preferredUnits;

  /// Kilometers unit option
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// Miles unit option
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMi;

  /// Section label on account setup screen
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// Male gender option
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// Female gender option
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// Other gender option
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// Date of birth field label
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirthLabel;

  /// Date of birth field placeholder
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get dateOfBirthHint;

  /// Generic continue button label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Heading on the home screen
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready!'**
  String get homeReady;

  /// Placeholder subtitle on the home screen
  ///
  /// In en, this message translates to:
  /// **'Home screen coming soon.'**
  String get homeComingSoon;

  /// Heading on the onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Let\'s build your plan'**
  String get onboardingIntroTitle;

  /// Subtitle on the onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Answer a few questions so we can create a training plan personalized to you. It takes about 3 minutes.'**
  String get onboardingIntroSubtitle;

  /// First bullet on onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Your race goal and timeline'**
  String get onboardingIntroFeature1;

  /// Second bullet on onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Fitness level and experience'**
  String get onboardingIntroFeature2;

  /// Third bullet on onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Schedule and preferences'**
  String get onboardingIntroFeature3;

  /// Footer note on onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'9 short sections · You can edit answers later'**
  String get onboardingIntroFooter;

  /// CTA button on the onboarding intro screen
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go'**
  String get letsGo;

  /// Heading on the goal screen
  ///
  /// In en, this message translates to:
  /// **'What\'s your goal?'**
  String get goalTitle;

  /// Subtitle on the goal screen
  ///
  /// In en, this message translates to:
  /// **'Tell us what you\'re training for and what outcome you want.'**
  String get goalSubtitle;

  /// Section label for race selection on goal screen
  ///
  /// In en, this message translates to:
  /// **'Goal race'**
  String get goalRaceLabel;

  /// 5K race option label
  ///
  /// In en, this message translates to:
  /// **'5K'**
  String get race5K;

  /// 10K race option label
  ///
  /// In en, this message translates to:
  /// **'10K'**
  String get race10K;

  /// Half marathon race option label
  ///
  /// In en, this message translates to:
  /// **'Half Marathon'**
  String get raceHalfMarathon;

  /// Marathon race option label
  ///
  /// In en, this message translates to:
  /// **'Marathon'**
  String get raceMarathon;

  /// Other/custom race option label
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get raceOther;

  /// Subtitle for the Other race option
  ///
  /// In en, this message translates to:
  /// **'Custom distance'**
  String get raceCustomDistance;

  /// Section label for race date question on goal screen
  ///
  /// In en, this message translates to:
  /// **'Do you have a race date?'**
  String get raceHasDateLabel;

  /// Generic yes option
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Generic no option
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Generic not sure option
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

  /// Race date picker label
  ///
  /// In en, this message translates to:
  /// **'Race date'**
  String get raceDateLabel;

  /// Date picker placeholder text
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get tapToSetDate;

  /// Section label for race priority on goal screen
  ///
  /// In en, this message translates to:
  /// **'What\'s your priority?'**
  String get priorityLabel;

  /// Priority option: finish the race
  ///
  /// In en, this message translates to:
  /// **'Just finish'**
  String get priorityJustFinish;

  /// Priority option: finish strong
  ///
  /// In en, this message translates to:
  /// **'Finish feeling strong'**
  String get priorityFinishStrong;

  /// Priority option: improve time
  ///
  /// In en, this message translates to:
  /// **'Improve my time'**
  String get priorityImproveTime;

  /// Priority option: build consistency
  ///
  /// In en, this message translates to:
  /// **'Build consistency'**
  String get priorityConsistency;

  /// Priority option: general fitness
  ///
  /// In en, this message translates to:
  /// **'General fitness'**
  String get priorityGeneralFitness;

  /// Section label for current race time on goal screen
  ///
  /// In en, this message translates to:
  /// **'Current race time'**
  String get currentRaceTime;

  /// Section label for target race time on goal screen
  ///
  /// In en, this message translates to:
  /// **'Target race time'**
  String get targetRaceTime;

  /// Time picker placeholder
  ///
  /// In en, this message translates to:
  /// **'Tap to set time'**
  String get tapToSetTime;

  /// Hours wheel column label on time picker
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get timePickerHours;

  /// Minutes wheel column label on time picker
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get timePickerMinutes;

  /// Seconds wheel column label on time picker
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get timePickerSeconds;

  /// Confirm button on time picker
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Heading on the current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Current Fitness'**
  String get fitnessTitle;

  /// Subtitle on the current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Help us understand where you\'re starting from.'**
  String get fitnessSubtitle;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Running experience'**
  String get runningExperienceLabel;

  /// Experience level option label
  ///
  /// In en, this message translates to:
  /// **'Brand new'**
  String get experienceBrandNew;

  /// Experience level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Never really run before'**
  String get experienceBrandNewSub;

  /// Experience level option label
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get experienceBeginner;

  /// Experience level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Some running, no consistent plan'**
  String get experienceBeginnerSub;

  /// Experience level option label
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get experienceIntermediate;

  /// Experience level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Run regularly, some race experience'**
  String get experienceIntermediateSub;

  /// Experience level option label
  ///
  /// In en, this message translates to:
  /// **'Experienced'**
  String get experienceExperienced;

  /// Experience level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Structured training, multiple races'**
  String get experienceExperiencedSub;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Can you currently run continuously for 10 minutes?'**
  String get canRun10MinLabel;

  /// Section label for optional benchmark on fitness screen
  ///
  /// In en, this message translates to:
  /// **'Optional benchmark'**
  String get optionalBenchmark;

  /// Badge label indicating a field is optional
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optionalBadge;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Current running days per week'**
  String get currentRunDaysLabel;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Average weekly volume'**
  String get weeklyVolumeLabel;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Longest recent run'**
  String get longestRunLabel;

  /// Longest run chip option for zero runs
  ///
  /// In en, this message translates to:
  /// **'I haven\'t done one'**
  String get longestRunNone;

  /// Longest run chip option for km users
  ///
  /// In en, this message translates to:
  /// **'Less than 5 km'**
  String get longestRunLessThan5km;

  /// Longest run chip option for mi users
  ///
  /// In en, this message translates to:
  /// **'Less than 3 mi'**
  String get longestRunLessThan3mi;

  /// Benchmark chip: 1-km run
  ///
  /// In en, this message translates to:
  /// **'1-km run time'**
  String get benchmarkKmRun;

  /// Benchmark chip: 1-km walk
  ///
  /// In en, this message translates to:
  /// **'1-km walk time'**
  String get benchmarkKmWalk;

  /// Benchmark chip: 1-mile run
  ///
  /// In en, this message translates to:
  /// **'1-mile run time'**
  String get benchmarkMiRun;

  /// Benchmark chip: 1-mile walk
  ///
  /// In en, this message translates to:
  /// **'1-mile walk time'**
  String get benchmarkMiWalk;

  /// Benchmark chip: 5K
  ///
  /// In en, this message translates to:
  /// **'5K time'**
  String get benchmark5K;

  /// Benchmark chip: 10K
  ///
  /// In en, this message translates to:
  /// **'10K time'**
  String get benchmark10K;

  /// Benchmark chip: half marathon
  ///
  /// In en, this message translates to:
  /// **'Half marathon time'**
  String get benchmarkHalfMarathon;

  /// Benchmark chip: skip option
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get benchmarkSkipForNow;

  /// Label shown above benchmark time picker
  ///
  /// In en, this message translates to:
  /// **'Your {benchmark}'**
  String benchmarkSelectedLabel(String benchmark);

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Can you currently complete your goal distance?'**
  String get canCompleteGoalLabel;

  /// Section label on current fitness screen
  ///
  /// In en, this message translates to:
  /// **'Have you done this race distance before?'**
  String get raceDistanceBeforeLabel;

  /// Segmented option: never done the distance
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get raceDistanceNever;

  /// Segmented option: done once
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get raceDistanceOnce;

  /// Segmented option: done 2-3 times
  ///
  /// In en, this message translates to:
  /// **'2-3'**
  String get raceDistance2to3;

  /// Segmented option: done 4 or more times
  ///
  /// In en, this message translates to:
  /// **'4+'**
  String get raceDistance4plus;

  /// Time picker bottom sheet title for benchmark
  ///
  /// In en, this message translates to:
  /// **'Your benchmark time'**
  String get yourBenchmarkTime;

  /// Heading on the schedule screen
  ///
  /// In en, this message translates to:
  /// **'Your Schedule'**
  String get scheduleTitle;

  /// Subtitle on the schedule screen
  ///
  /// In en, this message translates to:
  /// **'Tell us when you can realistically train.'**
  String get scheduleSubtitle;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Training days per week'**
  String get trainingDaysLabel;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Preferred long run day'**
  String get longRunDayLabel;

  /// Helper text under long run day label
  ///
  /// In en, this message translates to:
  /// **'This is the anchor of your weekly plan'**
  String get longRunDayHelper;

  /// Monday chip label
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// Tuesday chip label
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// Wednesday chip label
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// Thursday chip label
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// Friday chip label
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// Saturday chip label
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// Sunday chip label
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Weekday time available'**
  String get weekdayTimeLabel;

  /// 20 minute time chip
  ///
  /// In en, this message translates to:
  /// **'20 min'**
  String get time20min;

  /// 30 minute time chip
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get time30min;

  /// 45 minute time chip
  ///
  /// In en, this message translates to:
  /// **'45 min'**
  String get time45min;

  /// 60 minute time chip
  ///
  /// In en, this message translates to:
  /// **'60 min'**
  String get time60min;

  /// 75+ minute time chip
  ///
  /// In en, this message translates to:
  /// **'75+ min'**
  String get time75plusMin;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Weekend time available'**
  String get weekendTimeLabel;

  /// 90 minute time chip
  ///
  /// In en, this message translates to:
  /// **'90 min'**
  String get time90min;

  /// 2+ hours time chip
  ///
  /// In en, this message translates to:
  /// **'2+ hours'**
  String get time2plusHours;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Days that are hard to train'**
  String get hardDaysLabel;

  /// Helper text for multi-select sections
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get selectAllThatApply;

  /// Section label on schedule screen
  ///
  /// In en, this message translates to:
  /// **'Preferred time of day'**
  String get timeOfDayLabel;

  /// Time of day chip: early morning
  ///
  /// In en, this message translates to:
  /// **'Early morning'**
  String get timeOfDayEarlyMorning;

  /// Time of day chip: morning
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get timeOfDayMorning;

  /// Time of day chip: afternoon
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get timeOfDayAfternoon;

  /// Time of day chip: evening
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get timeOfDayEvening;

  /// Time of day chip: no preference
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get timeOfDayNoPreference;

  /// Heading on the health & injury screen
  ///
  /// In en, this message translates to:
  /// **'Health & Injury'**
  String get healthTitle;

  /// Subtitle on the health & injury screen
  ///
  /// In en, this message translates to:
  /// **'Help us understand any limitations so your plan keeps you safe.'**
  String get healthSubtitle;

  /// Section label on health screen
  ///
  /// In en, this message translates to:
  /// **'Current pain or injury?'**
  String get currentPainLabel;

  /// Pain option: no pain
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get painNo;

  /// Pain option: mild pain
  ///
  /// In en, this message translates to:
  /// **'Yes, mild'**
  String get painMild;

  /// Pain option: moderate pain
  ///
  /// In en, this message translates to:
  /// **'Yes, moderate'**
  String get painModerate;

  /// Pain option: severe pain
  ///
  /// In en, this message translates to:
  /// **'Yes, severe'**
  String get painSevere;

  /// Section label on health screen
  ///
  /// In en, this message translates to:
  /// **'Running-related injury in the last 12 months?'**
  String get recentInjuryLabel;

  /// Injury history option: no
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get injuryNo;

  /// Injury history option: once
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get injuryOnce;

  /// Injury history option: multiple
  ///
  /// In en, this message translates to:
  /// **'Multiple'**
  String get injuryMultiple;

  /// Section label on health screen
  ///
  /// In en, this message translates to:
  /// **'Health conditions affecting exercise?'**
  String get healthConditionsLabel;

  /// Section label on health screen
  ///
  /// In en, this message translates to:
  /// **'Plan preference'**
  String get planPreferenceLabel;

  /// Plan preference option label
  ///
  /// In en, this message translates to:
  /// **'Safest possible'**
  String get planSafest;

  /// Plan preference option subtitle
  ///
  /// In en, this message translates to:
  /// **'Prioritize injury prevention'**
  String get planSafestSub;

  /// Plan preference option label
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get planBalanced;

  /// Plan preference option subtitle
  ///
  /// In en, this message translates to:
  /// **'Mix of safety and progression'**
  String get planBalancedSub;

  /// Plan preference option label
  ///
  /// In en, this message translates to:
  /// **'Performance-focused'**
  String get planPerformance;

  /// Plan preference option subtitle
  ///
  /// In en, this message translates to:
  /// **'Push for results'**
  String get planPerformanceSub;

  /// Heading on the training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Training Preferences'**
  String get trainingPrefsTitle;

  /// Subtitle on the training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Customize how your plan is structured.'**
  String get trainingPrefsSubtitle;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Preferred guidance mode'**
  String get guidanceModeLabel;

  /// Guidance mode option label
  ///
  /// In en, this message translates to:
  /// **'Effort'**
  String get guidanceEffort;

  /// Guidance mode option subtitle
  ///
  /// In en, this message translates to:
  /// **'Train by perceived effort'**
  String get guidanceEffortSub;

  /// Guidance mode option label
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get guidancePace;

  /// Guidance mode option subtitle
  ///
  /// In en, this message translates to:
  /// **'Train by pace targets'**
  String get guidancePaceSub;

  /// Guidance mode option label
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get guidanceHeartRate;

  /// Guidance mode option subtitle
  ///
  /// In en, this message translates to:
  /// **'Train using HR zones'**
  String get guidanceHeartRateSub;

  /// Guidance mode option label
  ///
  /// In en, this message translates to:
  /// **'Decide for me'**
  String get guidanceDecideForMe;

  /// Guidance mode option subtitle
  ///
  /// In en, this message translates to:
  /// **'We\'ll pick the best approach'**
  String get guidanceDecideForMeSub;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Speed workouts included?'**
  String get speedWorkoutsLabel;

  /// Segmented option: only if needed
  ///
  /// In en, this message translates to:
  /// **'Only if needed'**
  String get onlyIfNeeded;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Strength training?'**
  String get strengthTrainingLabel;

  /// Strength training option: 1 day/week
  ///
  /// In en, this message translates to:
  /// **'1 day/week'**
  String get strength1DayWeek;

  /// Strength training option: 2 days/week
  ///
  /// In en, this message translates to:
  /// **'2 days/week'**
  String get strength2DaysWeek;

  /// Strength training option: 3 days/week
  ///
  /// In en, this message translates to:
  /// **'3 days/week'**
  String get strength3DaysWeek;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Where do you run most?'**
  String get runSurfaceLabel;

  /// Surface option: road
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get surfaceRoad;

  /// Surface option: treadmill
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get surfaceTreadmill;

  /// Surface option: track
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get surfaceTrack;

  /// Surface option: trail
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get surfaceTrail;

  /// Surface option: mixed
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get surfaceMixed;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get terrainLabel;

  /// Terrain option: flat
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get terrainFlat;

  /// Terrain option: some hills
  ///
  /// In en, this message translates to:
  /// **'Some hills'**
  String get terrainSomeHills;

  /// Terrain option: hilly
  ///
  /// In en, this message translates to:
  /// **'Hilly'**
  String get terrainHilly;

  /// Terrain option: mixed
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get terrainMixed;

  /// Section label on training preferences screen
  ///
  /// In en, this message translates to:
  /// **'Walk/run intervals?'**
  String get walkRunLabel;

  /// Heading on the watch & device screen
  ///
  /// In en, this message translates to:
  /// **'Watch & Device'**
  String get watchTitle;

  /// Subtitle on the watch & device screen
  ///
  /// In en, this message translates to:
  /// **'Let us know what data sources are available.'**
  String get watchSubtitle;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Do you use a watch or running device?'**
  String get usesWatchLabel;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Which device?'**
  String get deviceLabel;

  /// Device chip: Garmin
  ///
  /// In en, this message translates to:
  /// **'Garmin'**
  String get deviceGarmin;

  /// Device chip: Apple Watch
  ///
  /// In en, this message translates to:
  /// **'Apple Watch'**
  String get deviceAppleWatch;

  /// Device chip: COROS
  ///
  /// In en, this message translates to:
  /// **'COROS'**
  String get deviceCOROS;

  /// Device chip: Polar
  ///
  /// In en, this message translates to:
  /// **'Polar'**
  String get devicePolar;

  /// Device chip: Suunto
  ///
  /// In en, this message translates to:
  /// **'Suunto'**
  String get deviceSuunto;

  /// Device chip: Fitbit
  ///
  /// In en, this message translates to:
  /// **'Fitbit'**
  String get deviceFitbit;

  /// Device chip: other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get deviceOther;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'How should the app use your device data?'**
  String get deviceDataUsageLabel;

  /// Data usage option
  ///
  /// In en, this message translates to:
  /// **'Import runs automatically'**
  String get dataUsageImportAuto;

  /// Data usage option
  ///
  /// In en, this message translates to:
  /// **'Use heart rate only'**
  String get dataUsageHROnly;

  /// Data usage option
  ///
  /// In en, this message translates to:
  /// **'Use pace and distance only'**
  String get dataUsagePaceDistance;

  /// Data usage option
  ///
  /// In en, this message translates to:
  /// **'Use all available data'**
  String get dataUsageAll;

  /// Data usage option
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure'**
  String get dataUsageNotSure;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Use watch-based metrics?'**
  String get useWatchMetricsLabel;

  /// Segmented option: HR only
  ///
  /// In en, this message translates to:
  /// **'HR only'**
  String get hrOnly;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Which metrics?'**
  String get metricsLabel;

  /// Metric chip: heart rate
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get metricHeartRate;

  /// Metric chip: heart rate zones
  ///
  /// In en, this message translates to:
  /// **'Heart rate zones'**
  String get metricHRZones;

  /// Metric chip: pace
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get metricPace;

  /// Metric chip: distance
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get metricDistance;

  /// Metric chip: cadence
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get metricCadence;

  /// Metric chip: elevation
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get metricElevation;

  /// Metric chip: training load
  ///
  /// In en, this message translates to:
  /// **'Training load'**
  String get metricTrainingLoad;

  /// Metric chip: recovery time
  ///
  /// In en, this message translates to:
  /// **'Recovery time'**
  String get metricRecoveryTime;

  /// Metric chip: none
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get metricNone;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Heart-rate-based training zones?'**
  String get hrZonesLabel;

  /// Segmented option: if supported
  ///
  /// In en, this message translates to:
  /// **'If supported'**
  String get ifSupported;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Pace recommendations from watch?'**
  String get paceFromWatchLabel;

  /// Section label on watch screen
  ///
  /// In en, this message translates to:
  /// **'Auto-adjust plan from watch data?'**
  String get autoAdjustLabel;

  /// Auto-adjust option: auto
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoAdjustAuto;

  /// Auto-adjust option: ask first
  ///
  /// In en, this message translates to:
  /// **'Ask first'**
  String get autoAdjustAskFirst;

  /// Info card text for users without a watch
  ///
  /// In en, this message translates to:
  /// **'No worries! The app works great without a watch. We\'ll guide your training differently.'**
  String get noWatchInfo;

  /// Section label on watch screen for no-watch users
  ///
  /// In en, this message translates to:
  /// **'How should we guide your training?'**
  String get noWatchGuidanceLabel;

  /// No-watch guidance option label
  ///
  /// In en, this message translates to:
  /// **'Effort only'**
  String get noWatchEffortOnly;

  /// No-watch guidance option subtitle
  ///
  /// In en, this message translates to:
  /// **'Train by how it feels'**
  String get noWatchEffortOnlySub;

  /// No-watch guidance option label
  ///
  /// In en, this message translates to:
  /// **'Time-based runs'**
  String get noWatchTimeBased;

  /// No-watch guidance option subtitle
  ///
  /// In en, this message translates to:
  /// **'Run for set durations'**
  String get noWatchTimeBasedSub;

  /// No-watch guidance option label
  ///
  /// In en, this message translates to:
  /// **'Simple beginner guidance'**
  String get noWatchBeginner;

  /// No-watch guidance option subtitle
  ///
  /// In en, this message translates to:
  /// **'Step-by-step instructions'**
  String get noWatchBeginnerSub;

  /// No-watch guidance option label
  ///
  /// In en, this message translates to:
  /// **'Decide for me'**
  String get noWatchDecideForMe;

  /// No-watch guidance option subtitle
  ///
  /// In en, this message translates to:
  /// **'We\'ll pick what works best'**
  String get noWatchDecideForMeSub;

  /// Heading on the recovery & lifestyle screen
  ///
  /// In en, this message translates to:
  /// **'Recovery & Lifestyle'**
  String get recoveryTitle;

  /// Subtitle on the recovery & lifestyle screen
  ///
  /// In en, this message translates to:
  /// **'Quick questions to understand your recovery capacity.'**
  String get recoverySubtitle;

  /// Section label on recovery screen
  ///
  /// In en, this message translates to:
  /// **'Average weekday sleep'**
  String get sleepLabel;

  /// Sleep option: less than 5 hours
  ///
  /// In en, this message translates to:
  /// **'< 5h'**
  String get sleepLessThan5h;

  /// Sleep option: 5 to 6 hours
  ///
  /// In en, this message translates to:
  /// **'5–6h'**
  String get sleep5to6h;

  /// Sleep option: 6 to 7 hours
  ///
  /// In en, this message translates to:
  /// **'6–7h'**
  String get sleep6to7h;

  /// Sleep option: 7 to 8 hours
  ///
  /// In en, this message translates to:
  /// **'7–8h'**
  String get sleep7to8h;

  /// Sleep option: more than 8 hours
  ///
  /// In en, this message translates to:
  /// **'+8h'**
  String get sleep8plusH;

  /// Section label on recovery screen
  ///
  /// In en, this message translates to:
  /// **'Work / activity level'**
  String get workLevelLabel;

  /// Work level option label
  ///
  /// In en, this message translates to:
  /// **'Mostly desk'**
  String get workMostlyDesk;

  /// Work level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Sitting most of the day'**
  String get workMostlyDeskSub;

  /// Work level option label
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get workMixed;

  /// Work level option subtitle
  ///
  /// In en, this message translates to:
  /// **'Some sitting, some moving'**
  String get workMixedSub;

  /// Work level option label
  ///
  /// In en, this message translates to:
  /// **'Physical job'**
  String get workPhysical;

  /// Work level option subtitle
  ///
  /// In en, this message translates to:
  /// **'On your feet most of the day'**
  String get workPhysicalSub;

  /// Section label on recovery screen
  ///
  /// In en, this message translates to:
  /// **'Average stress level'**
  String get stressLabel;

  /// Stress option: low
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get stressLow;

  /// Stress option: moderate
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get stressModerate;

  /// Stress option: high
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get stressHigh;

  /// Section label on recovery screen
  ///
  /// In en, this message translates to:
  /// **'How do you feel day-to-day?'**
  String get dayFeelingLabel;

  /// Day feeling option
  ///
  /// In en, this message translates to:
  /// **'Usually fresh'**
  String get feelingFresh;

  /// Day feeling option
  ///
  /// In en, this message translates to:
  /// **'Sometimes tired'**
  String get feelingSometimesTired;

  /// Day feeling option
  ///
  /// In en, this message translates to:
  /// **'Often tired'**
  String get feelingOftenTired;

  /// Day feeling option
  ///
  /// In en, this message translates to:
  /// **'Always tired'**
  String get feelingAlwaysTired;

  /// Heading on the motivation screen
  ///
  /// In en, this message translates to:
  /// **'Motivation & Adherence'**
  String get motivationTitle;

  /// Subtitle on the motivation screen
  ///
  /// In en, this message translates to:
  /// **'Help us understand what drives you and what might get in the way.'**
  String get motivationSubtitle;

  /// Section label on motivation screen
  ///
  /// In en, this message translates to:
  /// **'Why are you doing this?'**
  String get whyDoingThisLabel;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Personal challenge'**
  String get motivationPersonalChallenge;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get motivationHealth;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Weight loss'**
  String get motivationWeightLoss;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Improve performance'**
  String get motivationImprovePerformance;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Race with friends/family'**
  String get motivationRaceFriends;

  /// Motivation chip
  ///
  /// In en, this message translates to:
  /// **'Build discipline'**
  String get motivationDiscipline;

  /// Motivation chip: other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get motivationOther;

  /// Section label on motivation screen
  ///
  /// In en, this message translates to:
  /// **'What gets in the way of consistency?'**
  String get barriersLabel;

  /// Barrier chip: time
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get barrierTime;

  /// Barrier chip: motivation
  ///
  /// In en, this message translates to:
  /// **'Motivation'**
  String get barrierMotivation;

  /// Barrier chip: fatigue
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get barrierFatigue;

  /// Barrier chip: stress
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get barrierStress;

  /// Barrier chip: pain or soreness
  ///
  /// In en, this message translates to:
  /// **'Pain or soreness'**
  String get barrierPain;

  /// Barrier chip: boredom
  ///
  /// In en, this message translates to:
  /// **'Boredom'**
  String get barrierBoredom;

  /// Barrier chip: don't know how
  ///
  /// In en, this message translates to:
  /// **'I don\'t know how to train'**
  String get barrierDontKnowHow;

  /// Barrier chip: other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get barrierOther;

  /// Section label for confidence slider on motivation screen
  ///
  /// In en, this message translates to:
  /// **'Confidence you\'ll stick with the plan'**
  String get confidenceLabel;

  /// Section label on motivation screen
  ///
  /// In en, this message translates to:
  /// **'Preferred coaching tone'**
  String get coachingToneLabel;

  /// Coaching tone option label
  ///
  /// In en, this message translates to:
  /// **'Simple and direct'**
  String get toneSimple;

  /// Coaching tone option subtitle
  ///
  /// In en, this message translates to:
  /// **'Straight to the point'**
  String get toneSimpleSub;

  /// Coaching tone option label
  ///
  /// In en, this message translates to:
  /// **'Encouraging'**
  String get toneEncouraging;

  /// Coaching tone option subtitle
  ///
  /// In en, this message translates to:
  /// **'Supportive and positive'**
  String get toneEncouragingSub;

  /// Coaching tone option label
  ///
  /// In en, this message translates to:
  /// **'Detailed and data-driven'**
  String get toneDetailed;

  /// Coaching tone option subtitle
  ///
  /// In en, this message translates to:
  /// **'Numbers and explanations'**
  String get toneDetailedSub;

  /// Coaching tone option label
  ///
  /// In en, this message translates to:
  /// **'Strict and performance-focused'**
  String get toneStrict;

  /// Coaching tone option subtitle
  ///
  /// In en, this message translates to:
  /// **'Push me hard'**
  String get toneStrictSub;

  /// Heading on the summary screen
  ///
  /// In en, this message translates to:
  /// **'Your Plan Summary'**
  String get summaryTitle;

  /// Subtitle on the summary screen
  ///
  /// In en, this message translates to:
  /// **'Review your selections before we build your plan.'**
  String get summarySubtitle;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Goal Race'**
  String get summaryGoalRace;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get summaryCurrentLevel;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get summarySchedule;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get summaryHealth;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get summaryTraining;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get summaryDevice;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get summaryRecovery;

  /// Summary card category label
  ///
  /// In en, this message translates to:
  /// **'Motivation'**
  String get summaryMotivation;

  /// Ready message at the bottom of the summary screen
  ///
  /// In en, this message translates to:
  /// **'Everything looks good. Ready to build your plan!'**
  String get summaryEverythingReady;

  /// Primary CTA button on the summary screen
  ///
  /// In en, this message translates to:
  /// **'Build My Plan'**
  String get buildMyPlan;

  /// Secondary button on the summary screen
  ///
  /// In en, this message translates to:
  /// **'Edit Answers'**
  String get editAnswers;

  /// Fitness detail for brand-new runners
  ///
  /// In en, this message translates to:
  /// **'Can run 10 min: {yesNo}'**
  String summaryCanRun10Min(String yesNo);

  /// Fitness detail for non-beginners
  ///
  /// In en, this message translates to:
  /// **'{days} days/wk · {volume} weekly'**
  String summaryFitnessDetail(String days, String volume);

  /// Schedule value in summary
  ///
  /// In en, this message translates to:
  /// **'{days} days per week'**
  String summaryDaysPerWeek(String days);

  /// Schedule detail in summary
  ///
  /// In en, this message translates to:
  /// **'Long run {longRun} · {time} · {weekday} weekdays'**
  String summaryScheduleDetail(String longRun, String time, String weekday);

  /// Health value when no pain
  ///
  /// In en, this message translates to:
  /// **'No current pain'**
  String get summaryNoPain;

  /// Health value when there is pain
  ///
  /// In en, this message translates to:
  /// **'Pain: {level}'**
  String summaryWithPain(String level);

  /// Health detail showing plan preference
  ///
  /// In en, this message translates to:
  /// **'{preference} plan preference'**
  String summaryPlanPref(String preference);

  /// Training value showing guidance mode
  ///
  /// In en, this message translates to:
  /// **'{mode}-based guidance'**
  String summaryGuidanceBased(String mode);

  /// Training detail in summary
  ///
  /// In en, this message translates to:
  /// **'Speed: {speed} · Strength: {strength} · {surface} · {terrain}'**
  String summaryTrainingDetail(
    String speed,
    String strength,
    String surface,
    String terrain,
  );

  /// Device value when watch is connected
  ///
  /// In en, this message translates to:
  /// **'{device} connected'**
  String summaryDeviceConnected(String device);

  /// Device value when no watch
  ///
  /// In en, this message translates to:
  /// **'No watch'**
  String get summaryNoWatch;

  /// Device detail when watch is connected
  ///
  /// In en, this message translates to:
  /// **'{usage} · HR zones: {hrZones} · Auto-adjust: {auto}'**
  String summaryDeviceDetail(String usage, String hrZones, String auto);

  /// Recovery value showing sleep hours
  ///
  /// In en, this message translates to:
  /// **'{hours} sleep'**
  String summarySleepHours(String hours);

  /// Recovery detail in summary
  ///
  /// In en, this message translates to:
  /// **'{work} · {stress} stress · {feeling}'**
  String summaryRecoveryDetail(String work, String stress, String feeling);

  /// Motivation detail in summary
  ///
  /// In en, this message translates to:
  /// **'{tone} tone · Confidence {score}/10'**
  String summaryMotivationDetail(String tone, String score);

  /// Heading on the plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Building Your Plan'**
  String get planGenerationTitle;

  /// Loading message 1 on plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Analyzing your fitness profile...'**
  String get planGenerationMsg1;

  /// Loading message 2 on plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Calculating optimal training zones...'**
  String get planGenerationMsg2;

  /// Loading message 3 on plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Building your weekly structure...'**
  String get planGenerationMsg3;

  /// Loading message 4 on plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Personalizing session targets...'**
  String get planGenerationMsg4;

  /// Loading message 5 on plan generation screen
  ///
  /// In en, this message translates to:
  /// **'Your plan is almost ready!'**
  String get planGenerationMsg5;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Plan name format e.g. '12-Week Half Marathon'
  ///
  /// In en, this message translates to:
  /// **'{weeks}-Week {race}'**
  String planReadyWeekPlanName(String weeks, String race);

  /// Heading on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready'**
  String get planReadyTitle;

  /// Label for the goal row on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get planReadyGoalLabel;

  /// Label for the schedule row on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get planReadyScheduleLabel;

  /// Label for the long runs row on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Long Runs'**
  String get planReadyLongRunsLabel;

  /// Label for the guidance mode row on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Guidance Mode'**
  String get planReadyGuidanceModeLabel;

  /// Goal description shown on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Complete a {race}'**
  String planReadyGoalDescription(String race);

  /// Schedule summary shown on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'{weeks} weeks • {runsPerWeek} runs/week'**
  String planReadyScheduleValue(String weeks, String runsPerWeek);

  /// Motivational paragraph on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Tailored exactly to your fitness and schedule. We\'ll safely build your endurance so you reach the finish line feeling strong.'**
  String get planReadyDescription;

  /// Primary CTA button on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'Start Plan'**
  String get planReadyStartPlan;

  /// Secondary CTA button on the plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'View Full Week'**
  String get planReadyViewFullWeek;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
