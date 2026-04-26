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
  /// **'StrivIQ'**
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
  /// **'Welcome to StrivIQ'**
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

  /// Loading label while creating an account
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get authLoadingSignUp;

  /// Loading label while logging in
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get authLoadingLogIn;

  /// Loading label while sending a password reset email
  ///
  /// In en, this message translates to:
  /// **'Sending reset link...'**
  String get authLoadingResetPassword;

  /// Loading label while signing out
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get authLoadingSignOut;

  /// Loading label while starting Google OAuth sign-in
  ///
  /// In en, this message translates to:
  /// **'Opening Google...'**
  String get authLoadingGoogleSignIn;

  /// OAuth button label on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Shown after sign up when email confirmation is required
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account.'**
  String get authSuccessCheckEmailForConfirmation;

  /// Shown after requesting a password reset email
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get authSuccessPasswordResetSent;

  /// Generic auth error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Shown when Supabase rejects sign-in credentials
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// Shown when sign-up is attempted with an existing email
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authErrorEmailAlreadyRegistered;

  /// Shown when Supabase rejects a weak password
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get authErrorWeakPassword;

  /// Shown when an email address is invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorInvalidEmail;

  /// Shown when sign-in is blocked until email confirmation
  ///
  /// In en, this message translates to:
  /// **'Confirm your email before logging in.'**
  String get authErrorEmailNotConfirmed;

  /// Shown when auth requests are temporarily rate limited
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get authErrorTooManyRequests;

  /// Shown when the request appears to fail due to connectivity
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection and try again.'**
  String get authErrorNetwork;

  /// Shown when auth actions are attempted without Supabase credentials
  ///
  /// In en, this message translates to:
  /// **'Authentication is not configured for this build.'**
  String get authErrorNotConfigured;

  /// Validation message when the email field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get authValidationEmailRequired;

  /// Validation message when the password field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authValidationPasswordRequired;

  /// Validation message when the password is shorter than the minimum length
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get authValidationPasswordTooShort;

  /// Validation message when the confirm password field is empty
  ///
  /// In en, this message translates to:
  /// **'Confirm your password.'**
  String get authValidationConfirmPasswordRequired;

  /// Validation message when the password confirmation does not match
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authValidationPasswordMismatch;

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

  /// Section label for elevation units on account setup screen
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get accountSetupShortDistanceUnits;

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

  /// Meters unit option
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitM;

  /// Feet unit option
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFt;

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

  /// Generic save changes button label
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// Button label to save a new goal
  ///
  /// In en, this message translates to:
  /// **'Set Goal'**
  String get setGoalButton;

  /// Button label to accept reviewed settings changes
  ///
  /// In en, this message translates to:
  /// **'Accept Changes'**
  String get settingsAcceptChanges;

  /// Title for the settings goal review screen
  ///
  /// In en, this message translates to:
  /// **'Review Changes'**
  String get settingsReviewChangesTitle;

  /// Primary CTA on the settings plan-ready screen
  ///
  /// In en, this message translates to:
  /// **'View Plan'**
  String get settingsViewPlan;

  /// Subtitle for the settings goal review screen
  ///
  /// In en, this message translates to:
  /// **'Review your {flowLabel} details and training preferences before applying them.'**
  String settingsReviewChangesSubtitle(String flowLabel);

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

  /// Step counter displayed on onboarding screens, e.g. '1 / 9'
  ///
  /// In en, this message translates to:
  /// **'{step} / {total}'**
  String onboardingStep(int step, int total);

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
  /// **'7 short sections · You can edit answers later'**
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

  /// Full weekday label for Monday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// Full weekday label for Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// Full weekday label for Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// Full weekday label for Thursday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// Full weekday label for Friday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// Full weekday label for Saturday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// Full weekday label for Sunday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

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
  /// **'Choose how you want your plan to feel.'**
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
  /// **'Long run {longRun} · Weekdays {weekday}'**
  String summaryScheduleDetail(String longRun, String weekday);

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

  /// Health detail showing injury history and health conditions
  ///
  /// In en, this message translates to:
  /// **'Injury history: {injury} · Conditions: {conditions}'**
  String summaryHealthDetail(String injury, String conditions);

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

  /// Heading shown when plan generation fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate your plan'**
  String get planGenerationErrorTitle;

  /// Subtitle shown when plan generation fails
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your answers are saved.'**
  String get planGenerationErrorSubtitle;

  /// Retry button label on plan generation error state
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get planGenerationRetry;

  /// Fallback button label on plan generation error state
  ///
  /// In en, this message translates to:
  /// **'Use Starter Plan for now'**
  String get planGenerationUseStarter;

  /// Banner shown on plan-ready screen when a starter plan is used instead of a generated one
  ///
  /// In en, this message translates to:
  /// **'This is a general starter plan, not personalized to your profile.'**
  String get planReadyStarterBanner;

  /// Action label to trigger personalized plan generation from the starter plan banner
  ///
  /// In en, this message translates to:
  /// **'Generate my personalized plan'**
  String get planReadyPersonalizeAction;

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

  /// Title of the home/today screen
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTitle;

  /// Section label for today's workout on the home screen
  ///
  /// In en, this message translates to:
  /// **'Today\'s Workout'**
  String get homeSectionTodaysWorkout;

  /// Section label for upcoming session on the home screen
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get homeSectionUpNext;

  /// Section label for weekly progress on the home screen
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get homeSectionThisWeek;

  /// Quick action button to log a past run on the home screen
  ///
  /// In en, this message translates to:
  /// **'Log Past Run'**
  String get homeLogPastRun;

  /// Quick action button to view the full weekly plan on the home screen
  ///
  /// In en, this message translates to:
  /// **'Full Week'**
  String get homeFullWeek;

  /// Stat label in the workout hero card
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get workoutDurationLabel;

  /// Stat label in the workout hero card
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get workoutDistanceLabel;

  /// Section label inside the target guidance box in the workout hero card
  ///
  /// In en, this message translates to:
  /// **'Target Guidance'**
  String get workoutTargetGuidanceLabel;

  /// Target guidance for easy run sessions
  ///
  /// In en, this message translates to:
  /// **'Build your aerobic base for the Half Marathon. Keep the pace conversational throughout.'**
  String get sessionDescEasyRun;

  /// Target guidance for interval sessions
  ///
  /// In en, this message translates to:
  /// **'{reps}×{repDistance} @ 5K pace. {recoverySeconds}s recovery jog between each rep.'**
  String sessionDescIntervals(
    int reps,
    String repDistance,
    int recoverySeconds,
  );

  /// Target guidance for long run sessions
  ///
  /// In en, this message translates to:
  /// **'Your key long run this week. Builds the endurance needed for your Half Marathon race day.'**
  String get sessionDescLongRun;

  /// Target guidance for recovery run sessions
  ///
  /// In en, this message translates to:
  /// **'Active recovery run to flush fatigue. Keep the effort very easy — slower than you think.'**
  String get sessionDescRecoveryRun;

  /// Target guidance for tempo run sessions
  ///
  /// In en, this message translates to:
  /// **'Comfortably hard effort. You should be able to speak a few words but not hold a conversation.'**
  String get sessionDescTempoRun;

  /// Primary button in the workout hero card
  ///
  /// In en, this message translates to:
  /// **'View Workout'**
  String get workoutViewDetailsButton;

  /// Stat label for runs completed in the week progress card
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get weekProgressRunsLabel;

  /// Stat label for volume in the week progress card
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get weekProgressVolumeLabel;

  /// Footer message in the week progress card
  ///
  /// In en, this message translates to:
  /// **'On track to hit {totalVolume} {unit} planned'**
  String weekProgressFooter(String totalVolume, String unit);

  /// Volume unit displayed on the home week progress card
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get homeVolumeUnit;

  /// Bottom nav tab label for the Today/Home tab
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Bottom nav tab label for the Plan tab
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// Bottom nav tab label for the Progress tab
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// Bottom nav tab label for the Settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Weekly plan screen title showing current week and total weeks
  ///
  /// In en, this message translates to:
  /// **'Week {week} of {total}'**
  String weeklyPlanTitle(String week, String total);

  /// Distance stat label in weekly plan summary card
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get weeklyPlanDistanceLabel;

  /// Time stat label in weekly plan summary card
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get weeklyPlanTimeLabel;

  /// Runs stat label in weekly plan summary card
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get weeklyPlanRunsLabel;

  /// Schedule section label in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get weeklyPlanScheduleLabel;

  /// Rest day session title
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get weeklyPlanRestTitle;

  /// Rest day subtitle text
  ///
  /// In en, this message translates to:
  /// **'Recovery day'**
  String get weeklyPlanRestSubtitle;

  /// Badge label on today's session row
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get weeklyPlanNowBadge;

  /// View full plan button label
  ///
  /// In en, this message translates to:
  /// **'View Full Plan'**
  String get weeklyPlanViewFullPlan;

  /// Easy run session type name
  ///
  /// In en, this message translates to:
  /// **'Easy Run'**
  String get weeklyPlanSessionEasyRun;

  /// Intervals session type name
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get weeklyPlanSessionIntervals;

  /// Long run session type name
  ///
  /// In en, this message translates to:
  /// **'Long Run'**
  String get weeklyPlanSessionLongRun;

  /// Recovery run session type name
  ///
  /// In en, this message translates to:
  /// **'Recovery Run'**
  String get weeklyPlanSessionRecoveryRun;

  /// Progression run session type name
  ///
  /// In en, this message translates to:
  /// **'Progression Run'**
  String get sessionTypeProgressionRun;

  /// Hill repeats session type name
  ///
  /// In en, this message translates to:
  /// **'Hill Repeats'**
  String get sessionTypeHillRepeats;

  /// Fartlek session type name
  ///
  /// In en, this message translates to:
  /// **'Fartlek'**
  String get sessionTypeFartlek;

  /// Threshold run session type name
  ///
  /// In en, this message translates to:
  /// **'Threshold Run'**
  String get sessionTypeThresholdRun;

  /// Race pace run session type name
  ///
  /// In en, this message translates to:
  /// **'Race Pace Run'**
  String get sessionTypeRacePaceRun;

  /// Cross training session type name
  ///
  /// In en, this message translates to:
  /// **'Cross Training'**
  String get sessionTypeCrossTraining;

  /// Rest day session type name
  ///
  /// In en, this message translates to:
  /// **'Rest Day'**
  String get sessionTypeRestDay;

  /// No description provided for @sessionCategoryEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get sessionCategoryEndurance;

  /// No description provided for @sessionCategorySpeedWork.
  ///
  /// In en, this message translates to:
  /// **'Speed Work'**
  String get sessionCategorySpeedWork;

  /// No description provided for @sessionCategoryThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get sessionCategoryThreshold;

  /// No description provided for @sessionCategoryRaceSpecific.
  ///
  /// In en, this message translates to:
  /// **'Race Specific'**
  String get sessionCategoryRaceSpecific;

  /// No description provided for @sessionCategoryRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get sessionCategoryRecovery;

  /// No description provided for @sessionCategoryRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get sessionCategoryRest;

  /// Monday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weeklyPlanDayMon;

  /// Tuesday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weeklyPlanDayTue;

  /// Wednesday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weeklyPlanDayWed;

  /// Thursday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weeklyPlanDayThu;

  /// Friday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weeklyPlanDayFri;

  /// Saturday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weeklyPlanDaySat;

  /// Sunday abbreviation in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weeklyPlanDaySun;

  /// Label for today's date box in weekly plan
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weeklyPlanDayToday;

  /// Progress screen title
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// Progress screen subtitle
  ///
  /// In en, this message translates to:
  /// **'You\'re building a solid habit. Keep it up.'**
  String get progressSubtitle;

  /// Subtitle on the streak banner
  ///
  /// In en, this message translates to:
  /// **'You\'re staying consistently active.'**
  String get progressStreakBannerSubtitle;

  /// Weekly volume chart section title
  ///
  /// In en, this message translates to:
  /// **'Weekly Volume'**
  String get progressWeeklyVolumeTitle;

  /// Trending up label in volume chart
  ///
  /// In en, this message translates to:
  /// **'Trending Up'**
  String get progressTrendingUp;

  /// Label below runs counter in volume chart
  ///
  /// In en, this message translates to:
  /// **'runs this week'**
  String get progressRunsThisWeek;

  /// Distance stat label
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get progressDistanceLabel;

  /// Time stat label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get progressTimeLabel;

  /// Streak stat label
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get progressStreakLabel;

  /// Runs stat label
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get progressRunsLabel;

  /// Completed label under runs count
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get progressRunsCompleted;

  /// Streak subtitle below streak count
  ///
  /// In en, this message translates to:
  /// **'{count} weeks in a row'**
  String progressStreakSubtitle(String count);

  /// Upward trend label on stat tiles
  ///
  /// In en, this message translates to:
  /// **'▲ {percent}% vs last mo'**
  String progressTrendUp(String percent);

  /// Downward trend label on stat tiles
  ///
  /// In en, this message translates to:
  /// **'▼ {percent}% vs last mo'**
  String progressTrendDown(String percent);

  /// Weeks unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'wks'**
  String get progressWeeksUnit;

  /// Hour unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get progressHourUnit;

  /// Minute unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get progressMinuteUnit;

  /// Longest run card title
  ///
  /// In en, this message translates to:
  /// **'Longest Run'**
  String get progressLongestRunTitle;

  /// Longest run improvement since plan start
  ///
  /// In en, this message translates to:
  /// **'+{distance} since start'**
  String progressLongestRunImproved(String distance);

  /// Recent sessions section title
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get progressRecentSessionsTitle;

  /// View all sessions link
  ///
  /// In en, this message translates to:
  /// **'View All ›'**
  String get progressViewAll;

  /// Title of the completed sessions screen
  ///
  /// In en, this message translates to:
  /// **'Completed Sessions'**
  String get completedSessionsTitle;

  /// Summary text shown at the top of the completed sessions screen
  ///
  /// In en, this message translates to:
  /// **'{count} sessions completed'**
  String completedSessionsSummary(String count);

  /// Empty state message for the completed sessions screen
  ///
  /// In en, this message translates to:
  /// **'No completed sessions yet'**
  String get completedSessionsEmpty;

  /// Tempo run session type name
  ///
  /// In en, this message translates to:
  /// **'Tempo Run'**
  String get progressSessionTempoRun;

  /// Tempo run session type name
  ///
  /// In en, this message translates to:
  /// **'Tempo Run'**
  String get sessionTypeTempoRun;

  /// Yesterday relative date label
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get progressYesterday;

  /// Tuesday label for recent session meta
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get progressTuesdayLabel;

  /// Last Sunday label for recent session meta
  ///
  /// In en, this message translates to:
  /// **'Last Sunday'**
  String get progressLastSunday;

  /// Week label prefix in volume chart (W1, W2...). S for Spanish (Semana).
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get progressWeekPrefix;

  /// Fallback profile name shown in settings when no name is stored
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get profileDefaultName;

  /// Short week label used in the home header
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String profileWeekShort(String week);

  /// Full week label used in the settings profile card
  ///
  /// In en, this message translates to:
  /// **'Week {week} of {total}'**
  String profileWeekFull(String week, String total);

  /// Training plan effort label: easy
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get trainingPlanEffortEasy;

  /// Training plan effort label: moderate
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get trainingPlanEffortModerate;

  /// Training plan effort label: hard
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get trainingPlanEffortHard;

  /// Training plan effort label: very easy
  ///
  /// In en, this message translates to:
  /// **'Very Easy'**
  String get trainingPlanEffortVeryEasy;

  /// Completed session subtitle with completion time
  ///
  /// In en, this message translates to:
  /// **'Completed · {time}'**
  String sessionCompletedAt(String time);

  /// Progress summary on the weekly calendar card
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} sessions done'**
  String weeklyCalendarSessionsDone(String completed, String total);

  /// Label for the current week stats card inside the volume chart
  ///
  /// In en, this message translates to:
  /// **'CURRENT WEEK'**
  String get progressCurrentWeek;

  /// Elevation stat label in the current week stats card
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get progressElevationLabel;

  /// Footer link in the weekly volume chart card
  ///
  /// In en, this message translates to:
  /// **'See Full Data'**
  String get progressSeeFullData;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// General section header on settings screen
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralSection;

  /// Account row label on settings screen
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Subscription row label on settings screen
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSubscription;

  /// Label for the active paid plan on the subscription screen
  ///
  /// In en, this message translates to:
  /// **'Active Plan'**
  String get settingsSubscriptionActivePlan;

  /// Visible plan name for the paid StrivIQ subscription
  ///
  /// In en, this message translates to:
  /// **'StrivIQ Pro'**
  String get settingsSubscriptionPlanName;

  /// Label for the next billing date on the subscription screen
  ///
  /// In en, this message translates to:
  /// **'Next Billing Date'**
  String get settingsSubscriptionNextBillingDate;

  /// Helper copy explaining the subscription auto-renew behavior
  ///
  /// In en, this message translates to:
  /// **'Your subscription will automatically renew. If you don\'t want to continue your subscription, cancel it before the next billing date.'**
  String get settingsSubscriptionAutoRenewNotice;

  /// Button and page title for the subscription cancellation flow
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get settingsCancelSubscription;

  /// Prompt shown at the top of the cancel subscription reasons screen
  ///
  /// In en, this message translates to:
  /// **'Please tell us why you\'re cancelling StrivIQ Pro'**
  String get settingsCancelSubscriptionPrompt;

  /// Cancellation reason: subscription cost is too high
  ///
  /// In en, this message translates to:
  /// **'It\'s too expensive'**
  String get settingsCancelSubscriptionReasonTooExpensive;

  /// Cancellation reason: not getting enough use from the subscription
  ///
  /// In en, this message translates to:
  /// **'I\'m not using it enough'**
  String get settingsCancelSubscriptionReasonNotUsingEnough;

  /// Cancellation reason: product is not helping enough
  ///
  /// In en, this message translates to:
  /// **'It\'s not helping me reach my goals'**
  String get settingsCancelSubscriptionReasonNotHelpingGoals;

  /// Cancellation reason: important features are missing
  ///
  /// In en, this message translates to:
  /// **'It\'s missing features I need'**
  String get settingsCancelSubscriptionReasonMissingFeatures;

  /// Cancellation reason: moving to another app
  ///
  /// In en, this message translates to:
  /// **'I\'m switching to another app'**
  String get settingsCancelSubscriptionReasonSwitchingApps;

  /// Cancellation reason: user is taking a break from running
  ///
  /// In en, this message translates to:
  /// **'I\'m taking a break from running'**
  String get settingsCancelSubscriptionReasonTakingBreak;

  /// Fallback cancellation reason option
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsCancelSubscriptionReasonOther;

  /// Secondary action to leave a flow without continuing
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get settingsNotNow;

  /// Title shown after the user submits cancellation reasons
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription in the store'**
  String get settingsSubscriptionCancellationInfoTitle;

  /// Helper copy shown after the user submits cancellation reasons
  ///
  /// In en, this message translates to:
  /// **'Thanks for sharing your feedback. To finish cancelling StrivIQ Pro, manage your subscription in the store where you purchased it.'**
  String get settingsSubscriptionCancellationInfoBody;

  /// Confirmation button label on the cancellation info dialog
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get settingsSubscriptionDialogButton;

  /// Integrations row label on settings screen
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settingsIntegrations;

  /// Available integrations section header on integrations settings screen
  ///
  /// In en, this message translates to:
  /// **'Available Integrations'**
  String get settingsAvailableIntegrationsSection;

  /// Apple Health integration row label
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get settingsAppleHealth;

  /// Health Connect integration row label
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get settingsHealthConnect;

  /// Profile section header on account settings screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsAccountProfileSection;

  /// Security section header on account settings screen
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsAccountSecuritySection;

  /// Name row label on account settings screen
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsAccountNameLabel;

  /// Sex row label on account settings screen
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get settingsAccountSexLabel;

  /// Placeholder value when an account field has not been set
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsAccountNotSet;

  /// Title shown on placeholder account security screens
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsAccountSecurityUnavailableTitle;

  /// Subtitle shown on the placeholder email screen inside account settings
  ///
  /// In en, this message translates to:
  /// **'Email changes will be available when account authentication is connected.'**
  String get settingsAccountEmailUnavailableSubtitle;

  /// Subtitle shown on the placeholder password screen inside account settings
  ///
  /// In en, this message translates to:
  /// **'Password changes will be available when account authentication is connected.'**
  String get settingsAccountPasswordUnavailableSubtitle;

  /// Plan & Goals section header
  ///
  /// In en, this message translates to:
  /// **'Plan & Goals'**
  String get settingsPlanGoalsSection;

  /// Row label to update training plan info
  ///
  /// In en, this message translates to:
  /// **'Update Plan Info'**
  String get settingsUpdatePlanInfo;

  /// Settings row label to edit the current goal
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get settingsEditGoal;

  /// Settings row label to create a new goal
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get settingsNewGoal;

  /// Settings row label to edit the training schedule
  ///
  /// In en, this message translates to:
  /// **'Change Schedule'**
  String get settingsChangeSchedule;

  /// Goal section label on the settings review screen
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get settingsSummaryGoalSection;

  /// Training section label on the settings review screen
  ///
  /// In en, this message translates to:
  /// **'Training Preferences'**
  String get settingsSummaryTrainingSection;

  /// Title on the intro screen before editing the current goal
  ///
  /// In en, this message translates to:
  /// **'Update the goal you are already training for'**
  String get settingsEditGoalIntroTitle;

  /// Subtitle on the intro screen before editing the current goal
  ///
  /// In en, this message translates to:
  /// **'You can review your race, date, priority, and time targets before saving the changes.'**
  String get settingsEditGoalIntroSubtitle;

  /// First explainer item for edit goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Adjust your race or target distance.'**
  String get settingsEditGoalIntroPointRace;

  /// Second explainer item for edit goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Update the race date if your timeline has changed.'**
  String get settingsEditGoalIntroPointDate;

  /// Third explainer item for edit goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Review your priority and pacing targets before saving.'**
  String get settingsEditGoalIntroPointPriority;

  /// Training preferences explainer item for edit goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Review your training preferences before finishing the update.'**
  String get settingsEditGoalIntroPointTraining;

  /// Title on the intro screen before creating a new goal
  ///
  /// In en, this message translates to:
  /// **'Set a brand-new goal for your training'**
  String get settingsNewGoalIntroTitle;

  /// Subtitle on the intro screen before creating a new goal
  ///
  /// In en, this message translates to:
  /// **'This flow starts fresh so you can choose a different target and save a new goal for your plan.'**
  String get settingsNewGoalIntroSubtitle;

  /// First explainer item for new goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Choose a new race or custom distance.'**
  String get settingsNewGoalIntroPointRace;

  /// Second explainer item for new goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Set a new date and timeline for the goal.'**
  String get settingsNewGoalIntroPointDate;

  /// Third explainer item for new goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Save a fresh goal without changing your schedule here.'**
  String get settingsNewGoalIntroPointPlan;

  /// Training preferences explainer item for new goal intro screen
  ///
  /// In en, this message translates to:
  /// **'Set the training preferences you want to use with this goal.'**
  String get settingsNewGoalIntroPointTraining;

  /// Preferences section header
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesSection;

  /// Language preference row label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// English language option in settings
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Spanish language option in settings
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get settingsLanguageSpanish;

  /// Current language value
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageValue;

  /// Units preference row label
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// Metric unit option in settings
  ///
  /// In en, this message translates to:
  /// **'Metric (km)'**
  String get settingsUnitsMetric;

  /// Imperial unit option in settings
  ///
  /// In en, this message translates to:
  /// **'Imperial (mi)'**
  String get settingsUnitsImperial;

  /// Distance units section title in settings
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get settingsUnitsDistanceSection;

  /// Elevation units section title in settings
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get settingsUnitsElevationSection;

  /// Meters unit option in settings
  ///
  /// In en, this message translates to:
  /// **'Meters (m)'**
  String get settingsUnitsMeters;

  /// Feet unit option in settings
  ///
  /// In en, this message translates to:
  /// **'Feet (ft)'**
  String get settingsUnitsFeet;

  /// Current units value
  ///
  /// In en, this message translates to:
  /// **'Metric (km)'**
  String get settingsUnitsValue;

  /// Notifications preference row label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Current notifications value
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsNotificationsValue;

  /// Connected Devices section header
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get settingsConnectedDevicesSection;

  /// Garmin Connect row label
  ///
  /// In en, this message translates to:
  /// **'Garmin Connect'**
  String get settingsGarminConnect;

  /// Connected device badge label
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsConnected;

  /// Empty state text shown when no wearable connections exist in settings integrations
  ///
  /// In en, this message translates to:
  /// **'No connected devices yet'**
  String get settingsNoConnectedDevices;

  /// Log out button label
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogOut;

  /// App version string shown at bottom of settings
  ///
  /// In en, this message translates to:
  /// **'StrivIQ v1.0.0 (Build 42)'**
  String get settingsVersion;

  /// Header title on the session detail screen
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get sessionDetailTitle;

  /// Session type badge label
  ///
  /// In en, this message translates to:
  /// **'Speed Work'**
  String get sessionDetailSessionType;

  /// Label for total distance stat tile
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get sessionDetailTotalDistanceLabel;

  /// Label for estimated duration stat tile
  ///
  /// In en, this message translates to:
  /// **'Est. Duration'**
  String get sessionDetailEstDurationLabel;

  /// Workout Structure section heading
  ///
  /// In en, this message translates to:
  /// **'Workout Structure'**
  String get sessionDetailWorkoutStructure;

  /// Warm-up phase title
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get sessionDetailWarmUp;

  /// Warm-up phase zone note
  ///
  /// In en, this message translates to:
  /// **'Easy pace, Zone 2'**
  String get sessionDetailWarmUpNote;

  /// Intervals phase title
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get sessionDetailIntervals;

  /// Intervals phase zone note
  ///
  /// In en, this message translates to:
  /// **'Hard effort, Zone 4'**
  String get sessionDetailIntervalsNote;

  /// Strides phase title
  ///
  /// In en, this message translates to:
  /// **'Strides'**
  String get sessionDetailStrides;

  /// Cool-down phase title
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get sessionDetailCoolDown;

  /// Cool-down phase duration
  ///
  /// In en, this message translates to:
  /// **'10 min'**
  String get sessionDetailCoolDownDuration;

  /// Cool-down phase zone note
  ///
  /// In en, this message translates to:
  /// **'Easy pace or walk'**
  String get sessionDetailCoolDownNote;

  /// Start Workout CTA button label
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get sessionDetailStartWorkout;

  /// Easy run warm-up duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseEasyRunWarmDuration(int minutes);

  /// Easy run warm-up note
  ///
  /// In en, this message translates to:
  /// **'Brisk walk + light dynamic leg swings'**
  String get sessionPhaseEasyRunWarmNote;

  /// Easy run main phase duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseEasyRunMainDuration(int minutes);

  /// Easy run main phase note
  ///
  /// In en, this message translates to:
  /// **'Conversational pace · Zone 2 · keep it relaxed'**
  String get sessionPhaseEasyRunMainNote;

  /// Easy run cool-down duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseEasyRunCoolDuration(int minutes);

  /// Easy run cool-down note
  ///
  /// In en, this message translates to:
  /// **'Walk it out · light static stretches'**
  String get sessionPhaseEasyRunCoolNote;

  /// Intervals warm-up duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseIntervalsWarmDuration(int minutes);

  /// Intervals warm-up note
  ///
  /// In en, this message translates to:
  /// **'Easy jog · strides at the end to prime the legs'**
  String get sessionPhaseIntervalsWarmNote;

  /// Intervals main phase duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseIntervalsMainDuration(int minutes);

  /// Intervals main phase note
  ///
  /// In en, this message translates to:
  /// **'{reps} × {repDistance} at hard effort · RPE 8–9'**
  String sessionPhaseIntervalsMainNote(int reps, String repDistance);

  /// Intervals main phase recovery note
  ///
  /// In en, this message translates to:
  /// **'{recoverySeconds} s easy jog recovery between each rep'**
  String sessionPhaseIntervalsMainRecovery(int recoverySeconds);

  /// Strides phase duration
  ///
  /// In en, this message translates to:
  /// **'{reps} × {seconds} s'**
  String sessionPhaseStridesDuration(int reps, int seconds);

  /// Strides phase note
  ///
  /// In en, this message translates to:
  /// **'Fast but relaxed · smooth form, not a sprint'**
  String get sessionPhaseStridesNote;

  /// Strides phase recovery note
  ///
  /// In en, this message translates to:
  /// **'{recoverySeconds} s easy walk or jog between strides'**
  String sessionPhaseStridesRecovery(int recoverySeconds);

  /// Intervals cool-down duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseIntervalsCoolDuration(int minutes);

  /// Intervals cool-down note
  ///
  /// In en, this message translates to:
  /// **'Easy jog → walk · full-body stretch'**
  String get sessionPhaseIntervalsCoolNote;

  /// Long run warm-up duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseLongRunWarmDuration(int minutes);

  /// Long run warm-up note
  ///
  /// In en, this message translates to:
  /// **'Very easy jog · ease into the effort'**
  String get sessionPhaseLongRunWarmNote;

  /// Long run main phase duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseLongRunMainDuration(int minutes);

  /// Long run main phase note
  ///
  /// In en, this message translates to:
  /// **'Steady easy effort · Zone 2 · stay comfortable throughout'**
  String get sessionPhaseLongRunMainNote;

  /// Long run cool-down duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseLongRunCoolDuration(int minutes);

  /// Long run cool-down note
  ///
  /// In en, this message translates to:
  /// **'Walk to finish · thorough stretch · refuel'**
  String get sessionPhaseLongRunCoolNote;

  /// Recovery run warm-up duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseRecoveryRunWarmDuration(int minutes);

  /// Recovery run warm-up note
  ///
  /// In en, this message translates to:
  /// **'Gentle walk to get moving'**
  String get sessionPhaseRecoveryRunWarmNote;

  /// Recovery run main phase duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseRecoveryRunMainDuration(int minutes);

  /// Recovery run main phase note
  ///
  /// In en, this message translates to:
  /// **'Very easy conversational pace · no watch pressure'**
  String get sessionPhaseRecoveryRunMainNote;

  /// Recovery run cool-down duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseRecoveryRunCoolDuration(int minutes);

  /// Recovery run cool-down note
  ///
  /// In en, this message translates to:
  /// **'Walk · foam roll if available'**
  String get sessionPhaseRecoveryRunCoolNote;

  /// Tempo run warm-up duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseTempoRunWarmDuration(int minutes);

  /// Tempo run warm-up note
  ///
  /// In en, this message translates to:
  /// **'Easy jog · build pace gradually'**
  String get sessionPhaseTempoRunWarmNote;

  /// Tempo run main phase duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseTempoRunMainDuration(int minutes);

  /// Tempo run main phase note
  ///
  /// In en, this message translates to:
  /// **'Comfortably hard effort · Zone 3–4'**
  String get sessionPhaseTempoRunMainNote;

  /// Tempo run cool-down duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionPhaseTempoRunCoolDuration(int minutes);

  /// Tempo run cool-down note
  ///
  /// In en, this message translates to:
  /// **'Easy jog → walk · stretch thoroughly'**
  String get sessionPhaseTempoRunCoolNote;

  /// Log session screen title
  ///
  /// In en, this message translates to:
  /// **'Log Session'**
  String get logSessionTitle;

  /// Label above planned session name on log session screen
  ///
  /// In en, this message translates to:
  /// **'Planned Session'**
  String get logSessionPlannedSession;

  /// Demo planned session name on log session screen
  ///
  /// In en, this message translates to:
  /// **'Morning Intervals'**
  String get logSessionSessionName;

  /// Duration metric card label
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get logSessionDurationLabel;

  /// Duration metric card subtitle
  ///
  /// In en, this message translates to:
  /// **'Active time'**
  String get logSessionActiveTime;

  /// Distance metric card label
  ///
  /// In en, this message translates to:
  /// **'DISTANCE'**
  String get logSessionDistanceLabel;

  /// Minutes unit label
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get logSessionMinUnit;

  /// Kilometers unit label
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get logSessionKmUnit;

  /// Pace subtitle on distance metric card
  ///
  /// In en, this message translates to:
  /// **'7:31 / km pace'**
  String get logSessionPaceValue;

  /// Average pace subtitle on distance metric card after a completed GPS run
  ///
  /// In en, this message translates to:
  /// **'{pace} / {unit} pace'**
  String logSessionAveragePaceSubtitle(String pace, String unit);

  /// Section heading for perceived effort selection
  ///
  /// In en, this message translates to:
  /// **'How did it feel?'**
  String get logSessionHowDidItFeel;

  /// Perceived effort option: easy
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get logSessionEasy;

  /// Perceived effort option: moderate
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get logSessionModerate;

  /// Perceived effort option: hard
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get logSessionHard;

  /// Perceived effort option: very hard
  ///
  /// In en, this message translates to:
  /// **'Very Hard'**
  String get logSessionVeryHard;

  /// Notes section heading
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get logSessionNotes;

  /// Optional label next to Notes heading
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get logSessionOptional;

  /// Placeholder text in the notes text area
  ///
  /// In en, this message translates to:
  /// **'How did the run go?'**
  String get logSessionNotesHint;

  /// Save session CTA button label
  ///
  /// In en, this message translates to:
  /// **'Save Session'**
  String get logSessionSaveButton;

  /// Header title on the active run tracking screen
  ///
  /// In en, this message translates to:
  /// **'Active Run'**
  String get activeRunTitle;

  /// Status pill indicating the active run screen is using mock tracking data
  ///
  /// In en, this message translates to:
  /// **'Demo tracking'**
  String get activeRunDemoTracking;

  /// Current pace metric label on the active run screen
  ///
  /// In en, this message translates to:
  /// **'CURRENT PACE'**
  String get activeRunCurrentPace;

  /// Compact target label in the collapsed active run Android notification
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get activeRunNotificationTargetShort;

  /// Compact distance label in the collapsed active run Android notification
  ///
  /// In en, this message translates to:
  /// **'Dist'**
  String get activeRunNotificationDistanceShort;

  /// Compact pace label in the collapsed active run Android notification
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get activeRunNotificationPaceShort;

  /// Elapsed time metric label on the active run screen
  ///
  /// In en, this message translates to:
  /// **'ELAPSED'**
  String get activeRunElapsed;

  /// Unit label for elapsed time metric
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get activeRunTimeUnit;

  /// Distance metric label on the active run screen
  ///
  /// In en, this message translates to:
  /// **'DISTANCE'**
  String get activeRunDistance;

  /// Average pace metric label on the active run screen
  ///
  /// In en, this message translates to:
  /// **'AVG PACE'**
  String get activeRunAveragePace;

  /// Target metric label on the active run screen
  ///
  /// In en, this message translates to:
  /// **'TARGET'**
  String get activeRunTarget;

  /// Pause CTA on the active run screen
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get activeRunPause;

  /// Button to resume the run after GPS was lost
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get activeRunResume;

  /// Finish CTA on the active run screen
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get activeRunFinish;

  /// Planned active run summary with duration and distance
  ///
  /// In en, this message translates to:
  /// **'{plannedDuration} · {plannedDistance}'**
  String activeRunPlannedSummary(
    String plannedDuration,
    String plannedDistance,
  );

  /// Planned active run summary with duration only
  ///
  /// In en, this message translates to:
  /// **'{plannedDuration}'**
  String activeRunPlannedDuration(String plannedDuration);

  /// Planned active run summary with distance only
  ///
  /// In en, this message translates to:
  /// **'{plannedDistance}'**
  String activeRunPlannedDistance(String plannedDistance);

  /// Fallback planned active run summary when no planned values exist
  ///
  /// In en, this message translates to:
  /// **'Guided run'**
  String get activeRunPlannedFallback;

  /// Active run guidance for easy runs
  ///
  /// In en, this message translates to:
  /// **'Keep it conversational and relaxed.'**
  String get activeRunGuidanceEasy;

  /// Active run guidance for long runs
  ///
  /// In en, this message translates to:
  /// **'Settle into a steady rhythm and protect the finish.'**
  String get activeRunGuidanceLong;

  /// Active run guidance for progression runs
  ///
  /// In en, this message translates to:
  /// **'Start controlled, then build effort one phase at a time.'**
  String get activeRunGuidanceProgression;

  /// Active run guidance for interval runs
  ///
  /// In en, this message translates to:
  /// **'Run the fast blocks with intent, then recover fully.'**
  String get activeRunGuidanceIntervals;

  /// Active run guidance for hill repeat runs
  ///
  /// In en, this message translates to:
  /// **'Drive the climb, recover on the way back down.'**
  String get activeRunGuidanceHills;

  /// Active run guidance for fartlek runs
  ///
  /// In en, this message translates to:
  /// **'Use surges when ready, then return to easy running.'**
  String get activeRunGuidanceFartlek;

  /// Active run guidance for tempo runs
  ///
  /// In en, this message translates to:
  /// **'Hold a strong pace you can control.'**
  String get activeRunGuidanceTempo;

  /// Active run guidance for threshold runs
  ///
  /// In en, this message translates to:
  /// **'Stay firm but smooth. Do not sprint.'**
  String get activeRunGuidanceThreshold;

  /// Active run guidance for race pace runs
  ///
  /// In en, this message translates to:
  /// **'Lock into goal pace and keep the effort even.'**
  String get activeRunGuidanceRacePace;

  /// Active run guidance for recovery runs
  ///
  /// In en, this message translates to:
  /// **'Keep this easy enough to feel better afterward.'**
  String get activeRunGuidanceRecovery;

  /// Active run status when user is going too fast
  ///
  /// In en, this message translates to:
  /// **'Ease off'**
  String get activeRunEaseOff;

  /// Active run status when user is going too slow
  ///
  /// In en, this message translates to:
  /// **'Pick it up'**
  String get activeRunPickUp;

  /// Active run status when user is on target
  ///
  /// In en, this message translates to:
  /// **'On target'**
  String get activeRunOnTarget;

  /// Active run status for work blocks
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get activeRunPush;

  /// Active run status for recovery blocks
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get activeRunRecover;

  /// Active run status or block label for a fartlek surge
  ///
  /// In en, this message translates to:
  /// **'Surge'**
  String get activeRunSurge;

  /// Easy block label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get activeRunEasyBlock;

  /// Fast target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get activeRunTargetFast;

  /// Climb target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Climb'**
  String get activeRunTargetClimb;

  /// Tempo target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get activeRunTargetTempo;

  /// Threshold target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get activeRunTargetThreshold;

  /// Race pace target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Race pace'**
  String get activeRunTargetRace;

  /// Easy target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get activeRunTargetEasy;

  /// Steady target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get activeRunTargetSteady;

  /// Build target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get activeRunTargetBuild;

  /// Surges target label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Surges'**
  String get activeRunTargetSurges;

  /// Unit label for pace-based active run target
  ///
  /// In en, this message translates to:
  /// **'pace'**
  String get activeRunTargetPaceUnit;

  /// Unit label for effort-based active run target
  ///
  /// In en, this message translates to:
  /// **'effort'**
  String get activeRunTargetEffortUnit;

  /// Focus panel title for hill repeat active run
  ///
  /// In en, this message translates to:
  /// **'Hill repeat focus'**
  String get activeRunHillFocusTitle;

  /// Focus panel title for interval active run
  ///
  /// In en, this message translates to:
  /// **'Interval focus'**
  String get activeRunIntervalFocusTitle;

  /// Current block label on active run focus panel
  ///
  /// In en, this message translates to:
  /// **'Current block'**
  String get activeRunCurrentBlock;

  /// Climb block label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Climb'**
  String get activeRunClimb;

  /// Fast repetition block label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Fast rep'**
  String get activeRunFastRep;

  /// Stride block label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Stride'**
  String get activeRunStride;

  /// Recovery block label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get activeRunRecovery;

  /// Repetition counter label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Rep'**
  String get activeRunRep;

  /// Remaining time in the current active run block
  ///
  /// In en, this message translates to:
  /// **'{remaining} remaining'**
  String activeRunBlockRemaining(String remaining);

  /// Next active run block preview
  ///
  /// In en, this message translates to:
  /// **'Next: {block}'**
  String activeRunNextBlock(String block);

  /// Focus panel title for progression active run
  ///
  /// In en, this message translates to:
  /// **'Progression phases'**
  String get activeRunProgressionFocusTitle;

  /// Steady phase label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get activeRunSteadyBlock;

  /// Strong phase label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get activeRunStrongBlock;

  /// Focus panel title for pace-controlled active runs
  ///
  /// In en, this message translates to:
  /// **'Pace control'**
  String get activeRunPaceFocusTitle;

  /// Control label on active run focus panel
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get activeRunControl;

  /// Footer guidance for pace-controlled active runs
  ///
  /// In en, this message translates to:
  /// **'Stay smooth inside the target band.'**
  String get activeRunPaceFocusFooter;

  /// Focus panel title for long run active screen
  ///
  /// In en, this message translates to:
  /// **'Long run focus'**
  String get activeRunLongFocusTitle;

  /// Focus label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get activeRunFocus;

  /// Reminder label on active run screen
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get activeRunReminder;

  /// Fuel reminder value on active run screen
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get activeRunFuel;

  /// Footer guidance for long run active screen
  ///
  /// In en, this message translates to:
  /// **'Sip water and check effort before the next mile.'**
  String get activeRunLongFocusFooter;

  /// Focus panel title for recovery run active screen
  ///
  /// In en, this message translates to:
  /// **'Recovery focus'**
  String get activeRunRecoveryFocusTitle;

  /// Focus panel title for easy run active screen
  ///
  /// In en, this message translates to:
  /// **'Easy run focus'**
  String get activeRunEasyFocusTitle;

  /// Relaxed control value on active run screen
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get activeRunRelaxed;

  /// Footer guidance for recovery run active screen
  ///
  /// In en, this message translates to:
  /// **'The goal is fresh legs, not a faster split.'**
  String get activeRunRecoveryFocusFooter;

  /// Footer guidance for easy run active screen
  ///
  /// In en, this message translates to:
  /// **'You should be able to speak in full sentences.'**
  String get activeRunEasyFocusFooter;

  /// Focus panel title for fartlek active run
  ///
  /// In en, this message translates to:
  /// **'Fartlek control'**
  String get activeRunFartlekFocusTitle;

  /// CTA to end a fartlek surge
  ///
  /// In en, this message translates to:
  /// **'End surge'**
  String get activeRunEndSurge;

  /// CTA to start a fartlek surge
  ///
  /// In en, this message translates to:
  /// **'Start surge'**
  String get activeRunStartSurge;

  /// Header title on the pre-run check screen
  ///
  /// In en, this message translates to:
  /// **'Pre-run Check'**
  String get preRunTitle;

  /// Large heading on the pre-run check screen
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get preRunHeading;

  /// Subtitle below heading on the pre-run check screen
  ///
  /// In en, this message translates to:
  /// **'Quick check to make sure today\'s interval session is still the right move.'**
  String get preRunSubtitle;

  /// Question label for legs feeling section
  ///
  /// In en, this message translates to:
  /// **'How do your legs feel today?'**
  String get preRunLegsQuestion;

  /// Legs feeling option: fresh
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get preRunFresh;

  /// Legs feeling option: normal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get preRunNormal;

  /// Legs feeling option: heavy
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get preRunHeavy;

  /// Question label for pain level section
  ///
  /// In en, this message translates to:
  /// **'Any pain right now?'**
  String get preRunPainQuestion;

  /// Pain level option: none
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get preRunNone;

  /// Pain level option: mild discomfort
  ///
  /// In en, this message translates to:
  /// **'Mild discomfort'**
  String get preRunMildDiscomfort;

  /// Pain level option: moderate pain
  ///
  /// In en, this message translates to:
  /// **'Moderate pain'**
  String get preRunModeratePain;

  /// Pain level option: sharp pain
  ///
  /// In en, this message translates to:
  /// **'Sharp pain'**
  String get preRunSharpPain;

  /// Question label for sleep quality section
  ///
  /// In en, this message translates to:
  /// **'How was your sleep?'**
  String get preRunSleepQuestion;

  /// Sleep quality option: great
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get preRunGreat;

  /// Sleep quality option: okay
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get preRunOkay;

  /// Sleep quality option: poor
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get preRunPoor;

  /// Question label for readiness section
  ///
  /// In en, this message translates to:
  /// **'Are you ready for this session?'**
  String get preRunReadinessQuestion;

  /// Readiness option: let's go
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get preRunLetsGo;

  /// Readiness option: not fully ready
  ///
  /// In en, this message translates to:
  /// **'Not fully ready'**
  String get preRunNotFullyReady;

  /// Continue CTA button on pre-run check screen
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get preRunContinue;

  /// Section title for workout preview on pre-run screen
  ///
  /// In en, this message translates to:
  /// **'Today\'s Workout'**
  String get preRunWorkoutPreviewTitle;

  /// Warm-up block in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'Warm-up {duration}'**
  String preRunWorkoutPreviewWarmUp(String duration);

  /// Strides block in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'{reps} × {seconds}s strides · {recoverySeconds}s recovery'**
  String preRunWorkoutPreviewStrides(
    int reps,
    int seconds,
    int recoverySeconds,
  );

  /// Main work block in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'Main {duration}'**
  String preRunWorkoutPreviewMain(String duration);

  /// Cool-down block in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'Cool-down {duration}'**
  String preRunWorkoutPreviewCoolDown(String duration);

  /// Repeated work and recovery block in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'{reps} × {work} work · {recovery} recovery'**
  String preRunWorkoutPreviewRepeat(int reps, String work, String recovery);

  /// Duration in minutes in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String preRunWorkoutPreviewDurationMinutes(int minutes);

  /// Duration in seconds in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String preRunWorkoutPreviewDurationSeconds(int seconds);

  /// Distance in meters in pre-run workout preview
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String preRunWorkoutPreviewDistanceMeters(int meters);

  /// Fallback label when a workout preview block has no duration or distance target
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get preRunWorkoutPreviewOpenDuration;

  /// Title of the workout options bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Workout Options'**
  String get workoutOptionsTitle;

  /// Skip workout option label
  ///
  /// In en, this message translates to:
  /// **'Skip Workout'**
  String get workoutOptionsSkipWorkout;

  /// Skip workout option description
  ///
  /// In en, this message translates to:
  /// **'Removes this session from this week schedule'**
  String get workoutOptionsSkipWorkoutDescription;

  /// Restore workout option label
  ///
  /// In en, this message translates to:
  /// **'Restore Workout'**
  String get workoutOptionsRestoreWorkout;

  /// Restore workout option description
  ///
  /// In en, this message translates to:
  /// **'Put this session back on the schedule'**
  String get workoutOptionsRestoreWorkoutDescription;

  /// Title of the full plan screen
  ///
  /// In en, this message translates to:
  /// **'Full Plan'**
  String get fullPlanTitle;

  /// Title of the training history screen
  ///
  /// In en, this message translates to:
  /// **'Training History'**
  String get trainingHistoryTitle;

  /// Informational note at the top of the full plan screen
  ///
  /// In en, this message translates to:
  /// **'This is your estimated full plan. It may change over time based on your progress and training adjustments.'**
  String get fullPlanNote;

  /// Label for the weeks stat column on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'WEEKS'**
  String get fullPlanWeeksLabel;

  /// Label for the total distance stat column on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'DISTANCE'**
  String get fullPlanDistanceLabel;

  /// Label for the total runs stat column on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'RUNS'**
  String get fullPlanRunsLabel;

  /// Week card heading, e.g. 'Week 4'
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String fullPlanWeekLabel(int number);

  /// Status badge label for the current week on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get fullPlanCurrentBadge;

  /// Status badge label for completed weeks on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get fullPlanCompletedBadge;

  /// Status badge label for upcoming weeks on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get fullPlanUpcomingBadge;

  /// Section label above the week list on the full plan screen
  ///
  /// In en, this message translates to:
  /// **'SCHEDULE'**
  String get fullPlanScheduleLabel;

  /// Shown on the today screen when no training plan has been generated yet
  ///
  /// In en, this message translates to:
  /// **'Your plan is being prepared'**
  String get planNotReadyMessage;

  /// Retry button label on the plan-not-ready empty state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get planNotReadyRetry;

  /// Base training phase label
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get phaseBase;

  /// Build training phase label
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get phaseBuild;

  /// Specific training phase label
  ///
  /// In en, this message translates to:
  /// **'Specific'**
  String get phaseSpecific;

  /// Peak training phase label
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get phasePeak;

  /// Taper/race training phase label
  ///
  /// In en, this message translates to:
  /// **'Taper'**
  String get phaseTaperRace;

  /// Title in the Android foreground notification when GPS tracking is active
  ///
  /// In en, this message translates to:
  /// **'Tracking Run'**
  String get activeRunGpsTrackingNotificationTitle;

  /// Body text in the Android foreground notification when GPS tracking is active
  ///
  /// In en, this message translates to:
  /// **'StrivIQ is recording your run'**
  String get activeRunGpsTrackingNotificationBody;

  /// Title of the dialog shown when GPS is required for a distance-based workout
  ///
  /// In en, this message translates to:
  /// **'GPS Required'**
  String get gpsRequiredTitle;

  /// Body text of the dialog shown when GPS is required for a distance-based workout
  ///
  /// In en, this message translates to:
  /// **'This workout has distance-based blocks and requires GPS to track your progress. Please enable location services to start this workout.'**
  String get gpsRequiredBody;

  /// Status label shown while acquiring GPS signal
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS signal'**
  String get gpsWaitForSignal;

  /// Warning label shown when GPS signal is weak
  ///
  /// In en, this message translates to:
  /// **'Weak GPS signal'**
  String get gpsWeakSignal;

  /// Status label shown when GPS signal is lost
  ///
  /// In en, this message translates to:
  /// **'GPS signal lost'**
  String get gpsLostSignal;

  /// Title chip label shown when GPS is acquiring signal
  ///
  /// In en, this message translates to:
  /// **'Acquiring'**
  String get gpsAcquiringTitle;

  /// Title chip label shown when GPS signal is weak
  ///
  /// In en, this message translates to:
  /// **'Weak Signal'**
  String get gpsWeakTitle;

  /// Button label to enable device location services from GPS required dialog
  ///
  /// In en, this message translates to:
  /// **'Enable Location Services'**
  String get gpsEnableLocationServices;

  /// Title chip label shown when GPS signal is lost
  ///
  /// In en, this message translates to:
  /// **'Signal Lost'**
  String get gpsLostTitle;

  /// CTA button to end the active run
  ///
  /// In en, this message translates to:
  /// **'End Run'**
  String get activeRunEndRun;

  /// Status label shown when the active run is in timer-only mode without GPS
  ///
  /// In en, this message translates to:
  /// **'Timer only'**
  String get activeRunTimerOnlyLabel;

  /// Button label to open app settings when location permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get preRunOpenSettings;

  /// Button label to open location settings when location service is disabled
  ///
  /// In en, this message translates to:
  /// **'Enable Location Services'**
  String get preRunEnableLocationServices;

  /// Button label to start run in timer-only mode without GPS
  ///
  /// In en, this message translates to:
  /// **'Timer-only Mode'**
  String get preRunTimerOnlyMode;

  /// Title of dialog when device location services are disabled
  ///
  /// In en, this message translates to:
  /// **'Location Services Disabled'**
  String get locationServiceDisabledTitle;

  /// Body text of dialog when device location services are disabled
  ///
  /// In en, this message translates to:
  /// **'Please enable location services to track your run with GPS.'**
  String get locationServiceDisabledBody;

  /// Title of dialog when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location Permission Denied'**
  String get locationPermissionDeniedTitle;

  /// Body text of dialog when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to track your run. Please grant permission in Settings.'**
  String get locationPermissionDeniedBody;

  /// Title of non-dismissible modal when GPS is lost during a distance-based block
  ///
  /// In en, this message translates to:
  /// **'GPS Signal Lost'**
  String get activeRunGpsLostAutoPauseTitle;

  /// Body of non-dismissible modal when GPS is lost during a distance-based block
  ///
  /// In en, this message translates to:
  /// **'GPS signal was lost. Your run has been auto-paused. Tap Resume to continue when GPS recovers, or End Run to finish now.'**
  String get activeRunGpsLostAutoPauseBody;

  /// Title of dismissible warning when GPS is lost during a duration-based block
  ///
  /// In en, this message translates to:
  /// **'GPS Signal Weak'**
  String get activeRunGpsLostWarningTitle;

  /// Body of dismissible warning when GPS is lost during a duration-based block
  ///
  /// In en, this message translates to:
  /// **'GPS signal is weak. Distance tracking is paused but your timer is still running.'**
  String get activeRunGpsLostWarningBody;

  /// Button to wait for GPS signal to recover
  ///
  /// In en, this message translates to:
  /// **'Wait for GPS'**
  String get activeRunWaitForGps;

  /// Button to dismiss the GPS warning modal
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get activeRunDismiss;

  /// Title of error dialog when timer-only mode is requested for distance-based workout
  ///
  /// In en, this message translates to:
  /// **'Timer-Only Not Supported'**
  String get activeRunTimerOnlyRestrictionTitle;
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
