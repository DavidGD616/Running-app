// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'StrivIQ';

  @override
  String get languageCodeEN => 'EN';

  @override
  String get languageCodeES => 'ES';

  @override
  String get splashTagline => 'Entrena más inteligente. Corre más fuerte.';

  @override
  String get welcomeTitle => 'Bienvenido a StrivIQ';

  @override
  String get welcomeSubtitle =>
      'Tu entrenador personal de running. Crea un plan adaptado a tus objetivos, nivel de forma física y horario.';

  @override
  String get welcomeFeature1 => 'Planes de entrenamiento personalizados';

  @override
  String get welcomeFeature2 => 'Progresión potenciada por IA';

  @override
  String get welcomeFeature3 => 'Horarios flexibles';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get logInTitle => 'Bienvenido de nuevo';

  @override
  String get logInSubtitle => 'Inicia sesión para continuar tu entrenamiento.';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get emailHint => 'tu@ejemplo.com';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get passwordHint => 'Ingresa tu contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get dontHaveAccount => '¿No tienes cuenta? Regístrate';

  @override
  String get signUpTitle => 'Crea tu cuenta';

  @override
  String get signUpSubtitle =>
      'Empieza a crear tu plan de entrenamiento personalizado.';

  @override
  String get passwordHintSignUp => 'Al menos 6 caracteres';

  @override
  String get confirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get confirmPasswordHint => 'Vuelve a ingresar tu contraseña';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get forgotPasswordTitle => '¿Olvidaste tu contraseña?';

  @override
  String get forgotPasswordSubtitle =>
      'Ingresa tu correo y te enviaremos un enlace para restablecerla.';

  @override
  String get sendResetLink => 'Enviar enlace';

  @override
  String get backToLogIn => 'Volver a iniciar sesión';

  @override
  String get authLoadingSignUp => 'Creando cuenta...';

  @override
  String get authLoadingLogIn => 'Iniciando sesión...';

  @override
  String get authLoadingResetPassword => 'Enviando enlace...';

  @override
  String get authLoadingSignOut => 'Cerrando sesión...';

  @override
  String get authLoadingGoogleSignIn => 'Abriendo Google...';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get authSuccessCheckEmailForConfirmation =>
      'Revisa tu correo para confirmar tu cuenta.';

  @override
  String get authSuccessPasswordResetSent =>
      'Correo de restablecimiento enviado. Revisa tu bandeja de entrada.';

  @override
  String get authErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get authErrorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'Ya existe una cuenta con este correo.';

  @override
  String get authErrorWeakPassword =>
      'La contraseña es demasiado débil. Usa al menos 6 caracteres.';

  @override
  String get authErrorInvalidEmail => 'Ingresa un correo válido.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma tu correo antes de iniciar sesión.';

  @override
  String get authErrorTooManyRequests =>
      'Demasiados intentos. Espera un momento y vuelve a intentarlo.';

  @override
  String get authErrorNetwork =>
      'Error de red. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get authErrorNotConfigured =>
      'La autenticación no está configurada en esta compilación.';

  @override
  String get authValidationEmailRequired => 'Ingresa tu correo.';

  @override
  String get authValidationPasswordRequired => 'Ingresa tu contraseña.';

  @override
  String get authValidationPasswordTooShort => 'Usa al menos 6 caracteres.';

  @override
  String get authValidationConfirmPasswordRequired => 'Confirma tu contraseña.';

  @override
  String get authValidationPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get accountSetupTitle => 'Configuración de cuenta';

  @override
  String get accountSetupSubtitle => 'Ayúdanos a personalizar tu experiencia.';

  @override
  String get preferredUnits => 'Unidades preferidas';

  @override
  String get accountSetupShortDistanceUnits => 'Elevación';

  @override
  String get unitKm => 'km';

  @override
  String get unitMi => 'mi';

  @override
  String get unitM => 'm';

  @override
  String get unitFt => 'ft';

  @override
  String get genderLabel => 'Género';

  @override
  String get genderMale => 'Hombre';

  @override
  String get genderFemale => 'Mujer';

  @override
  String get genderOther => 'Otro';

  @override
  String get dateOfBirthLabel => 'Fecha de nacimiento';

  @override
  String get dateOfBirthHint => 'DD / MM / AAAA';

  @override
  String get continueButton => 'Continuar';

  @override
  String get saveChangesButton => 'Guardar cambios';

  @override
  String get setGoalButton => 'Definir objetivo';

  @override
  String get settingsAcceptChanges => 'Aceptar cambios';

  @override
  String get settingsReviewChangesTitle => 'Revisar cambios';

  @override
  String get settingsViewPlan => 'Ver plan';

  @override
  String settingsReviewChangesSubtitle(String flowLabel) {
    return 'Revisa los detalles de $flowLabel y tus preferencias de entrenamiento antes de aplicarlos.';
  }

  @override
  String get homeReady => '¡Tu plan está listo!';

  @override
  String get homeComingSoon => 'Pantalla de inicio próximamente.';

  @override
  String onboardingStep(int step, int total) {
    return '$step / $total';
  }

  @override
  String get onboardingIntroTitle => 'Construyamos tu plan';

  @override
  String get onboardingIntroSubtitle =>
      'Responde algunas preguntas para que podamos crear un plan de entrenamiento personalizado para ti. Tarda unos 3 minutos.';

  @override
  String get onboardingIntroFeature1 => 'Tu objetivo de carrera y cronograma';

  @override
  String get onboardingIntroFeature2 => 'Nivel de forma física y experiencia';

  @override
  String get onboardingIntroFeature3 => 'Horario y preferencias';

  @override
  String get onboardingIntroFooter =>
      '7 secciones cortas · Puedes editar tus respuestas después';

  @override
  String get letsGo => '¡Empecemos!';

  @override
  String get goalTitle => '¿Cuál es tu objetivo?';

  @override
  String get goalSubtitle =>
      'Cuéntanos para qué entrenas y qué resultado quieres lograr.';

  @override
  String get goalRaceLabel => 'Carrera objetivo';

  @override
  String get race5K => '5K';

  @override
  String get race10K => '10K';

  @override
  String get raceHalfMarathon => 'Media Maratón';

  @override
  String get raceMarathon => 'Maratón';

  @override
  String get raceOther => 'Otro';

  @override
  String get raceCustomDistance => 'Distancia personalizada';

  @override
  String get raceHasDateLabel => '¿Tienes una fecha de carrera?';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get notSure => 'No estoy seguro';

  @override
  String get raceDateLabel => 'Fecha de carrera';

  @override
  String get tapToSetDate => 'DD / MM / AAAA';

  @override
  String get priorityLabel => '¿Cuál es tu prioridad?';

  @override
  String get priorityJustFinish => 'Solo terminar';

  @override
  String get priorityFinishStrong => 'Terminar sintiéndome bien';

  @override
  String get priorityImproveTime => 'Mejorar mi tiempo';

  @override
  String get priorityConsistency => 'Desarrollar constancia';

  @override
  String get priorityGeneralFitness => 'Forma física general';

  @override
  String get currentRaceTime => 'Tiempo actual de carrera';

  @override
  String get targetRaceTime => 'Tiempo objetivo de carrera';

  @override
  String get tapToSetTime => 'Toca para establecer el tiempo';

  @override
  String get timePickerHours => 'h';

  @override
  String get timePickerMinutes => 'min';

  @override
  String get timePickerSeconds => 'seg';

  @override
  String get confirm => 'Confirmar';

  @override
  String get fitnessTitle => 'Estado Físico Actual';

  @override
  String get fitnessSubtitle => 'Ayúdanos a entender desde dónde empiezas.';

  @override
  String get runningExperienceLabel => 'Experiencia corriendo';

  @override
  String get experienceBrandNew => 'Principiante total';

  @override
  String get experienceBrandNewSub => 'Nunca he corrido de verdad';

  @override
  String get experienceBeginner => 'Principiante';

  @override
  String get experienceBeginnerSub => 'Algo de running, sin plan consistente';

  @override
  String get experienceIntermediate => 'Intermedio';

  @override
  String get experienceIntermediateSub =>
      'Corro regularmente, algo de experiencia en carreras';

  @override
  String get experienceExperienced => 'Experimentado';

  @override
  String get experienceExperiencedSub =>
      'Entrenamiento estructurado, varias carreras';

  @override
  String get canRun10MinLabel =>
      '¿Puedes correr de forma continua durante 10 minutos?';

  @override
  String get optionalBenchmark => 'Referencia opcional';

  @override
  String get optionalBadge => 'opcional';

  @override
  String get currentRunDaysLabel => 'Días de running actuales por semana';

  @override
  String get weeklyVolumeLabel => 'Volumen semanal promedio';

  @override
  String get longestRunLabel => 'Carrera más larga reciente';

  @override
  String get longestRunNone => 'No he hecho ninguna';

  @override
  String get longestRunLessThan5km => 'Menos de 5 km';

  @override
  String get longestRunLessThan3mi => 'Menos de 3 mi';

  @override
  String get benchmarkKmRun => 'Tiempo corriendo 1 km';

  @override
  String get benchmarkKmWalk => 'Tiempo caminando 1 km';

  @override
  String get benchmarkMiRun => 'Tiempo corriendo 1 milla';

  @override
  String get benchmarkMiWalk => 'Tiempo caminando 1 milla';

  @override
  String get benchmark5K => 'Tiempo 5K';

  @override
  String get benchmark10K => 'Tiempo 10K';

  @override
  String get benchmarkHalfMarathon => 'Tiempo media maratón';

  @override
  String get benchmarkSkipForNow => 'Omitir por ahora';

  @override
  String benchmarkSelectedLabel(String benchmark) {
    return 'Tu $benchmark';
  }

  @override
  String get canCompleteGoalLabel =>
      '¿Puedes completar tu distancia objetivo actualmente?';

  @override
  String get raceDistanceBeforeLabel => '¿Has corrido esta distancia antes?';

  @override
  String get raceDistanceNever => 'Nunca';

  @override
  String get raceDistanceOnce => 'Una vez';

  @override
  String get raceDistance2to3 => '2-3';

  @override
  String get raceDistance4plus => '4+';

  @override
  String get yourBenchmarkTime => 'Tu tiempo de referencia';

  @override
  String get scheduleTitle => 'Tu Horario';

  @override
  String get scheduleSubtitle =>
      'Cuéntanos cuándo puedes entrenar de forma realista.';

  @override
  String get trainingDaysLabel => 'Días de entrenamiento por semana';

  @override
  String get longRunDayLabel => 'Día preferido para la carrera larga';

  @override
  String get longRunDayHelper => 'Este es el pilar de tu plan semanal';

  @override
  String get dayMon => 'Lun';

  @override
  String get dayTue => 'Mar';

  @override
  String get dayWed => 'Mié';

  @override
  String get dayThu => 'Jue';

  @override
  String get dayFri => 'Vie';

  @override
  String get daySat => 'Sáb';

  @override
  String get daySun => 'Dom';

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get weekdayTimeLabel => 'Tiempo disponible entre semana';

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
  String get weekendTimeLabel => 'Tiempo disponible el fin de semana';

  @override
  String get time90min => '90 min';

  @override
  String get time2plusHours => '2+ horas';

  @override
  String get hardDaysLabel => 'Días difíciles para entrenar';

  @override
  String get selectAllThatApply => 'Selecciona todos los que apliquen';

  @override
  String get timeOfDayLabel => 'Hora preferida del día';

  @override
  String get timeOfDayEarlyMorning => 'Madrugada';

  @override
  String get timeOfDayMorning => 'Mañana';

  @override
  String get timeOfDayAfternoon => 'Tarde';

  @override
  String get timeOfDayEvening => 'Noche';

  @override
  String get timeOfDayNoPreference => 'Sin preferencia';

  @override
  String get healthTitle => 'Salud y Lesiones';

  @override
  String get healthSubtitle =>
      'Ayúdanos a entender tus limitaciones para que tu plan sea seguro.';

  @override
  String get currentPainLabel => '¿Tienes dolor o lesión actualmente?';

  @override
  String get painNo => 'No';

  @override
  String get painMild => 'Sí, leve';

  @override
  String get painModerate => 'Sí, moderado';

  @override
  String get painSevere => 'Sí, severo';

  @override
  String get recentInjuryLabel =>
      '¿Tuviste una lesión relacionada con el running en los últimos 12 meses?';

  @override
  String get injuryNo => 'No';

  @override
  String get injuryOnce => 'Una vez';

  @override
  String get injuryMultiple => 'Varias veces';

  @override
  String get healthConditionsLabel =>
      '¿Tienes condiciones de salud que afecten el ejercicio?';

  @override
  String get planPreferenceLabel => 'Preferencia del plan';

  @override
  String get planSafest => 'Lo más seguro posible';

  @override
  String get planSafestSub => 'Priorizar la prevención de lesiones';

  @override
  String get planBalanced => 'Equilibrado';

  @override
  String get planBalancedSub => 'Mezcla de seguridad y progresión';

  @override
  String get planPerformance => 'Enfocado en rendimiento';

  @override
  String get planPerformanceSub => 'Buscar resultados';

  @override
  String get trainingPrefsTitle => 'Preferencias de Entrenamiento';

  @override
  String get trainingPrefsSubtitle =>
      'Elige cómo quieres que se sienta tu plan.';

  @override
  String get guidanceModeLabel => 'Modo de guía preferido';

  @override
  String get guidanceEffort => 'Esfuerzo';

  @override
  String get guidanceEffortSub => 'Entrena por esfuerzo percibido';

  @override
  String get guidancePace => 'Ritmo';

  @override
  String get guidancePaceSub => 'Entrena por objetivos de ritmo';

  @override
  String get guidanceHeartRate => 'Frecuencia cardíaca';

  @override
  String get guidanceHeartRateSub => 'Entrena usando zonas de FC';

  @override
  String get guidanceDecideForMe => 'Decidir por mí';

  @override
  String get guidanceDecideForMeSub => 'Elegiremos el mejor enfoque';

  @override
  String get speedWorkoutsLabel => '¿Incluir entrenamientos de velocidad?';

  @override
  String get onlyIfNeeded => 'Solo si es necesario';

  @override
  String get strengthTrainingLabel => '¿Entrenamiento de fuerza?';

  @override
  String get strength1DayWeek => '1 día/semana';

  @override
  String get strength2DaysWeek => '2 días/semana';

  @override
  String get strength3DaysWeek => '3 días/semana';

  @override
  String get runSurfaceLabel => '¿Dónde corres más?';

  @override
  String get surfaceRoad => 'Asfalto';

  @override
  String get surfaceTreadmill => 'Cinta';

  @override
  String get surfaceTrack => 'Pista';

  @override
  String get surfaceTrail => 'Trail';

  @override
  String get surfaceMixed => 'Mixto';

  @override
  String get terrainLabel => 'Terreno';

  @override
  String get terrainFlat => 'Llano';

  @override
  String get terrainSomeHills => 'Algunas cuestas';

  @override
  String get terrainHilly => 'Con cuestas';

  @override
  String get terrainMixed => 'Mixto';

  @override
  String get watchTitle => 'Reloj y Dispositivo';

  @override
  String get watchSubtitle =>
      'Cuéntanos qué fuentes de datos tienes disponibles.';

  @override
  String get usesWatchLabel => '¿Usas un reloj o dispositivo para correr?';

  @override
  String get deviceLabel => '¿Qué dispositivo?';

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
  String get deviceOther => 'Otro';

  @override
  String get deviceDataUsageLabel =>
      '¿Cómo debe usar la app los datos de tu dispositivo?';

  @override
  String get dataUsageImportAuto => 'Importar carreras automáticamente';

  @override
  String get dataUsageHROnly => 'Usar solo frecuencia cardíaca';

  @override
  String get dataUsagePaceDistance => 'Usar solo ritmo y distancia';

  @override
  String get dataUsageAll => 'Usar todos los datos disponibles';

  @override
  String get dataUsageNotSure => 'No estoy seguro';

  @override
  String get useWatchMetricsLabel => '¿Usar métricas del reloj?';

  @override
  String get hrOnly => 'Solo FC';

  @override
  String get metricsLabel => '¿Qué métricas?';

  @override
  String get metricHeartRate => 'Frecuencia cardíaca';

  @override
  String get metricHRZones => 'Zonas de frecuencia cardíaca';

  @override
  String get metricPace => 'Ritmo';

  @override
  String get metricDistance => 'Distancia';

  @override
  String get metricCadence => 'Cadencia';

  @override
  String get metricElevation => 'Elevación';

  @override
  String get metricTrainingLoad => 'Carga de entrenamiento';

  @override
  String get metricRecoveryTime => 'Tiempo de recuperación';

  @override
  String get metricNone => 'Ninguna';

  @override
  String get hrZonesLabel => '¿Zonas de entrenamiento basadas en FC?';

  @override
  String get ifSupported => 'Si es compatible';

  @override
  String get paceFromWatchLabel => '¿Recomendaciones de ritmo del reloj?';

  @override
  String get autoAdjustLabel =>
      '¿Ajustar plan automáticamente con datos del reloj?';

  @override
  String get autoAdjustAuto => 'Automático';

  @override
  String get autoAdjustAskFirst => 'Preguntar primero';

  @override
  String get noWatchInfo =>
      '¡No te preocupes! La app funciona muy bien sin reloj. Guiaremos tu entrenamiento de otra manera.';

  @override
  String get noWatchGuidanceLabel => '¿Cómo debemos guiar tu entrenamiento?';

  @override
  String get noWatchEffortOnly => 'Solo esfuerzo';

  @override
  String get noWatchEffortOnlySub => 'Entrena por cómo te sientes';

  @override
  String get noWatchTimeBased => 'Carreras por tiempo';

  @override
  String get noWatchTimeBasedSub => 'Corre durante duraciones fijas';

  @override
  String get noWatchBeginner => 'Guía simple para principiantes';

  @override
  String get noWatchBeginnerSub => 'Instrucciones paso a paso';

  @override
  String get noWatchDecideForMe => 'Decidir por mí';

  @override
  String get noWatchDecideForMeSub => 'Elegiremos lo que mejor funcione';

  @override
  String get recoveryTitle => 'Recuperación y Estilo de Vida';

  @override
  String get recoverySubtitle =>
      'Preguntas rápidas para entender tu capacidad de recuperación.';

  @override
  String get sleepLabel => 'Horas de sueño promedio entre semana';

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
  String get workLevelLabel => 'Nivel de actividad laboral';

  @override
  String get workMostlyDesk => 'Principalmente sedentario';

  @override
  String get workMostlyDeskSub => 'Sentado la mayor parte del día';

  @override
  String get workMixed => 'Mixto';

  @override
  String get workMixedSub => 'Algo sentado, algo en movimiento';

  @override
  String get workPhysical => 'Trabajo físico';

  @override
  String get workPhysicalSub => 'De pie la mayor parte del día';

  @override
  String get stressLabel => 'Nivel de estrés promedio';

  @override
  String get stressLow => 'Bajo';

  @override
  String get stressModerate => 'Moderado';

  @override
  String get stressHigh => 'Alto';

  @override
  String get dayFeelingLabel => '¿Cómo te sientes día a día?';

  @override
  String get feelingFresh => 'Generalmente fresco';

  @override
  String get feelingSometimesTired => 'A veces cansado';

  @override
  String get feelingOftenTired => 'Frecuentemente cansado';

  @override
  String get feelingAlwaysTired => 'Siempre cansado';

  @override
  String get motivationTitle => 'Motivación y Adherencia';

  @override
  String get motivationSubtitle =>
      'Ayúdanos a entender qué te mueve y qué puede interponerse.';

  @override
  String get whyDoingThisLabel => '¿Por qué estás haciendo esto?';

  @override
  String get motivationPersonalChallenge => 'Reto personal';

  @override
  String get motivationHealth => 'Salud';

  @override
  String get motivationWeightLoss => 'Pérdida de peso';

  @override
  String get motivationImprovePerformance => 'Mejorar rendimiento';

  @override
  String get motivationRaceFriends => 'Correr con amigos/familia';

  @override
  String get motivationDiscipline => 'Desarrollar disciplina';

  @override
  String get motivationOther => 'Otro';

  @override
  String get barriersLabel => '¿Qué interfiere con tu constancia?';

  @override
  String get barrierTime => 'Tiempo';

  @override
  String get barrierMotivation => 'Motivación';

  @override
  String get barrierFatigue => 'Fatiga';

  @override
  String get barrierStress => 'Estrés';

  @override
  String get barrierPain => 'Dolor o malestar';

  @override
  String get barrierBoredom => 'Aburrimiento';

  @override
  String get barrierDontKnowHow => 'No sé cómo entrenar';

  @override
  String get barrierOther => 'Otro';

  @override
  String get confidenceLabel => 'Confianza en que seguirás el plan';

  @override
  String get coachingToneLabel => 'Tono de entrenamiento preferido';

  @override
  String get toneSimple => 'Simple y directo';

  @override
  String get toneSimpleSub => 'Al grano';

  @override
  String get toneEncouraging => 'Motivador';

  @override
  String get toneEncouragingSub => 'Apoyo y positividad';

  @override
  String get toneDetailed => 'Detallado y basado en datos';

  @override
  String get toneDetailedSub => 'Números y explicaciones';

  @override
  String get toneStrict => 'Estricto y orientado al rendimiento';

  @override
  String get toneStrictSub => 'Exígeme';

  @override
  String get summaryTitle => 'Resumen de Tu Plan';

  @override
  String get summarySubtitle =>
      'Revisa tus selecciones antes de crear tu plan.';

  @override
  String get summaryGoalRace => 'Carrera Objetivo';

  @override
  String get summaryCurrentLevel => 'Nivel Actual';

  @override
  String get summarySchedule => 'Horario';

  @override
  String get summaryHealth => 'Salud';

  @override
  String get summaryTraining => 'Entrenamiento';

  @override
  String get summaryDevice => 'Dispositivo';

  @override
  String get summaryRecovery => 'Recuperación';

  @override
  String get summaryMotivation => 'Motivación';

  @override
  String get summaryEverythingReady =>
      'Todo se ve bien. ¡Listo para crear tu plan!';

  @override
  String get buildMyPlan => 'Crear Mi Plan';

  @override
  String get editAnswers => 'Editar Respuestas';

  @override
  String summaryCanRun10Min(String yesNo) {
    return 'Puede correr 10 min: $yesNo';
  }

  @override
  String summaryFitnessDetail(String days, String volume) {
    return '$days días/sem · $volume semanales';
  }

  @override
  String summaryDaysPerWeek(String days) {
    return '$days días por semana';
  }

  @override
  String summaryScheduleDetail(String longRun, String weekday) {
    return 'Tirada larga $longRun · Entre semana $weekday';
  }

  @override
  String get summaryNoPain => 'Sin dolor actualmente';

  @override
  String summaryWithPain(String level) {
    return 'Dolor: $level';
  }

  @override
  String summaryHealthDetail(String injury, String conditions) {
    return 'Historial de lesiones: $injury · Condiciones: $conditions';
  }

  @override
  String summaryPlanPref(String preference) {
    return 'Preferencia: $preference';
  }

  @override
  String summaryGuidanceBased(String mode) {
    return 'Guía basada en $mode';
  }

  @override
  String summaryDeviceConnected(String device) {
    return '$device conectado';
  }

  @override
  String get summaryNoWatch => 'Sin reloj';

  @override
  String summaryDeviceDetail(String usage, String hrZones, String auto) {
    return '$usage · Zonas FC: $hrZones · Ajuste auto: $auto';
  }

  @override
  String summarySleepHours(String hours) {
    return '$hours de sueño';
  }

  @override
  String summaryRecoveryDetail(String work, String stress, String feeling) {
    return '$work · $stress de estrés · $feeling';
  }

  @override
  String summaryMotivationDetail(String tone, String score) {
    return 'Tono $tone · Confianza $score/10';
  }

  @override
  String get planGenerationTitle => 'Construyendo Tu Plan';

  @override
  String get planGenerationMsg1 => 'Analizando tu perfil físico...';

  @override
  String get planGenerationMsg2 =>
      'Calculando zonas de entrenamiento óptimas...';

  @override
  String get planGenerationMsg3 => 'Construyendo tu estructura semanal...';

  @override
  String get planGenerationMsg4 => 'Personalizando objetivos de sesión...';

  @override
  String get planGenerationMsg5 => '¡Tu plan está casi listo!';

  @override
  String get planGenerationErrorTitle => 'No pudimos generar tu plan';

  @override
  String get planGenerationErrorSubtitle =>
      'Algo salió mal. Tus respuestas están guardadas.';

  @override
  String get planGenerationRetry => 'Intentar de nuevo';

  @override
  String get planGenerationUseStarter => 'Usar plan de inicio por ahora';

  @override
  String get planReadyStarterBanner =>
      'Este es un plan de inicio general, no personalizado a tu perfil.';

  @override
  String get planReadyPersonalizeAction => 'Generar mi plan personalizado';

  @override
  String get monthJanuary => 'Enero';

  @override
  String get monthFebruary => 'Febrero';

  @override
  String get monthMarch => 'Marzo';

  @override
  String get monthApril => 'Abril';

  @override
  String get monthMay => 'Mayo';

  @override
  String get monthJune => 'Junio';

  @override
  String get monthJuly => 'Julio';

  @override
  String get monthAugust => 'Agosto';

  @override
  String get monthSeptember => 'Septiembre';

  @override
  String get monthOctober => 'Octubre';

  @override
  String get monthNovember => 'Noviembre';

  @override
  String get monthDecember => 'Diciembre';

  @override
  String get errorGeneric => 'Algo salió mal. Por favor intenta de nuevo.';

  @override
  String planReadyWeekPlanName(String weeks, String race) {
    return '$race de $weeks semanas';
  }

  @override
  String get planReadyTitle => 'Tu plan está listo';

  @override
  String get planReadyGoalLabel => 'Objetivo';

  @override
  String get planReadyScheduleLabel => 'Horario';

  @override
  String get planReadyLongRunsLabel => 'Carreras largas';

  @override
  String get planReadyGuidanceModeLabel => 'Modo de guía';

  @override
  String planReadyGoalDescription(String race) {
    return 'Completar $race';
  }

  @override
  String planReadyScheduleValue(String weeks, String runsPerWeek) {
    return '$weeks semanas • $runsPerWeek carreras/semana';
  }

  @override
  String get planReadyDescription =>
      'Diseñado exactamente para tu condición física y horario. Construiremos tu resistencia de forma segura para que llegues a la meta sintiéndote fuerte.';

  @override
  String get planReadyStartPlan => 'Iniciar plan';

  @override
  String get planReadyViewFullWeek => 'Ver semana completa';

  @override
  String get homeTitle => 'Hoy';

  @override
  String get homeSectionTodaysWorkout => 'Entrenamiento de Hoy';

  @override
  String get homeSectionUpNext => 'A Continuación';

  @override
  String get homeSectionThisWeek => 'Esta Semana';

  @override
  String get homeLogPastRun => 'Registrar Carrera';

  @override
  String get homeFullWeek => 'Semana Completa';

  @override
  String get workoutDurationLabel => 'Duración';

  @override
  String get workoutDistanceLabel => 'Distancia';

  @override
  String get workoutTargetGuidanceLabel => 'Objetivo de Entrenamiento';

  @override
  String get sessionDescEasyRun =>
      'Construye tu base aeróbica para la Media Maratón. Mantén un ritmo en el que puedas conversar.';

  @override
  String sessionDescIntervals(
    int reps,
    String repDistance,
    int recoverySeconds,
  ) {
    return '$reps×$repDistance al ritmo de 5K. ${recoverySeconds}s de trote de recuperación entre cada repetición.';
  }

  @override
  String get sessionDescLongRun =>
      'Tu carrera larga clave de esta semana. Construye la resistencia necesaria para el día de tu Media Maratón.';

  @override
  String get sessionDescRecoveryRun =>
      'Carrera de recuperación activa para eliminar la fatiga. Mantén el esfuerzo muy suave, más lento de lo que crees.';

  @override
  String get sessionDescTempoRun =>
      'Esfuerzo cómodamente intenso. Puedes decir algunas palabras pero no mantener una conversación.';

  @override
  String get workoutViewDetailsButton => 'Ver Entrenamiento';

  @override
  String get weekProgressRunsLabel => 'Carreras';

  @override
  String get weekProgressVolumeLabel => 'Volumen';

  @override
  String weekProgressFooter(String totalVolume, String unit) {
    return 'En camino de alcanzar $totalVolume $unit planificados';
  }

  @override
  String get homeVolumeUnit => 'km';

  @override
  String get tabToday => 'Hoy';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabProgress => 'Progreso';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String weeklyPlanTitle(String week, String total) {
    return 'Semana $week de $total';
  }

  @override
  String get weeklyPlanDistanceLabel => 'Distancia';

  @override
  String get weeklyPlanTimeLabel => 'Tiempo';

  @override
  String get weeklyPlanRunsLabel => 'Carreras';

  @override
  String get weeklyPlanScheduleLabel => 'Horario';

  @override
  String get weeklyPlanRestTitle => 'Descanso';

  @override
  String get weeklyPlanRestSubtitle => 'Día de recuperación';

  @override
  String get weeklyPlanNowBadge => 'Ahora';

  @override
  String get weeklyPlanViewFullPlan => 'Ver Plan Completo';

  @override
  String get weeklyPlanSessionEasyRun => 'Carrera Suave';

  @override
  String get weeklyPlanSessionIntervals => 'Intervalos';

  @override
  String get weeklyPlanSessionLongRun => 'Carrera Larga';

  @override
  String get weeklyPlanSessionRecoveryRun => 'Carrera de Recuperación';

  @override
  String get sessionTypeProgressionRun => 'Carrera de Progresión';

  @override
  String get sessionTypeHillRepeats => 'Subidas';

  @override
  String get sessionTypeFartlek => 'Fartlek';

  @override
  String get sessionTypeThresholdRun => 'Carrera de Umbral';

  @override
  String get sessionTypeRacePaceRun => 'Carrera a Ritmo de Carrera';

  @override
  String get sessionTypeCrossTraining => 'Entrenamiento Cruzado';

  @override
  String get sessionTypeRestDay => 'Día de Descanso';

  @override
  String get sessionCategoryEndurance => 'Resistencia';

  @override
  String get sessionCategorySpeedWork => 'Velocidad';

  @override
  String get sessionCategoryThreshold => 'Umbral';

  @override
  String get sessionCategoryRaceSpecific => 'Específico de Carrera';

  @override
  String get sessionCategoryRecovery => 'Recuperación';

  @override
  String get sessionCategoryRest => 'Descanso';

  @override
  String get weeklyPlanDayMon => 'Lun';

  @override
  String get weeklyPlanDayTue => 'Mar';

  @override
  String get weeklyPlanDayWed => 'Mié';

  @override
  String get weeklyPlanDayThu => 'Jue';

  @override
  String get weeklyPlanDayFri => 'Vie';

  @override
  String get weeklyPlanDaySat => 'Sáb';

  @override
  String get weeklyPlanDaySun => 'Dom';

  @override
  String get weeklyPlanDayToday => 'Hoy';

  @override
  String get progressTitle => 'Progreso';

  @override
  String get progressSubtitle =>
      'Estás construyendo un buen hábito. Sigue así.';

  @override
  String get progressStreakBannerSubtitle =>
      'Te estás manteniendo activo de forma constante.';

  @override
  String get progressWeeklyVolumeTitle => 'Volumen Semanal';

  @override
  String get progressTrendingUp => 'En Alza';

  @override
  String get progressRunsThisWeek => 'carreras esta semana';

  @override
  String get progressDistanceLabel => 'Distancia';

  @override
  String get progressTimeLabel => 'Tiempo';

  @override
  String get progressStreakLabel => 'Racha';

  @override
  String get progressRunsLabel => 'Carreras';

  @override
  String get progressRunsCompleted => 'Completadas';

  @override
  String progressStreakSubtitle(String count) {
    return '$count semanas seguidas';
  }

  @override
  String progressTrendUp(String percent) {
    return '▲ $percent% vs mes ant.';
  }

  @override
  String progressTrendDown(String percent) {
    return '▼ $percent% vs mes ant.';
  }

  @override
  String get progressWeeksUnit => 'sem';

  @override
  String get progressHourUnit => 'h';

  @override
  String get progressMinuteUnit => 'm';

  @override
  String get progressLongestRunTitle => 'Carrera Más Larga';

  @override
  String progressLongestRunImproved(String distance) {
    return '+$distance desde el inicio';
  }

  @override
  String get progressRecentSessionsTitle => 'Sesiones Recientes';

  @override
  String get progressViewAll => 'Ver Todo ›';

  @override
  String get completedSessionsTitle => 'Sesiones Completadas';

  @override
  String completedSessionsSummary(String count) {
    return '$count sesiones completadas';
  }

  @override
  String get completedSessionsEmpty => 'Aún no hay sesiones completadas';

  @override
  String get progressSessionTempoRun => 'Carrera Tempo';

  @override
  String get sessionTypeTempoRun => 'Carrera Tempo';

  @override
  String get progressYesterday => 'Ayer';

  @override
  String get progressTuesdayLabel => 'Martes';

  @override
  String get progressLastSunday => 'Último Domingo';

  @override
  String get progressWeekPrefix => 'S';

  @override
  String get profileDefaultName => 'Nombre de usuario';

  @override
  String profileWeekShort(String week) {
    return 'Semana $week';
  }

  @override
  String profileWeekFull(String week, String total) {
    return 'Semana $week de $total';
  }

  @override
  String get trainingPlanEffortEasy => 'Fácil';

  @override
  String get trainingPlanEffortModerate => 'Moderado';

  @override
  String get trainingPlanEffortHard => 'Duro';

  @override
  String get trainingPlanEffortVeryEasy => 'Muy fácil';

  @override
  String sessionCompletedAt(String time) {
    return 'Completado · $time';
  }

  @override
  String weeklyCalendarSessionsDone(String completed, String total) {
    return '$completed de $total sesiones completadas';
  }

  @override
  String get progressCurrentWeek => 'SEMANA ACTUAL';

  @override
  String get progressElevationLabel => 'Elevación';

  @override
  String get progressSeeFullData => 'Ver datos completos';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsSubscription => 'Suscripción';

  @override
  String get settingsSubscriptionActivePlan => 'Plan activo';

  @override
  String get settingsSubscriptionPlanName => 'StrivIQ Pro';

  @override
  String get settingsSubscriptionNextBillingDate => 'Próxima fecha de cobro';

  @override
  String get settingsSubscriptionAutoRenewNotice =>
      'Tu suscripción se renovará automáticamente. Si no quieres continuar con tu suscripción, cancélala antes de la próxima fecha de cobro.';

  @override
  String get settingsCancelSubscription => 'Cancelar suscripción';

  @override
  String get settingsCancelSubscriptionPrompt =>
      'Cuéntanos por qué estás cancelando StrivIQ Pro';

  @override
  String get settingsCancelSubscriptionReasonTooExpensive =>
      'Es demasiado caro';

  @override
  String get settingsCancelSubscriptionReasonNotUsingEnough =>
      'No lo estoy usando lo suficiente';

  @override
  String get settingsCancelSubscriptionReasonNotHelpingGoals =>
      'No me está ayudando a alcanzar mis objetivos';

  @override
  String get settingsCancelSubscriptionReasonMissingFeatures =>
      'Le faltan funciones que necesito';

  @override
  String get settingsCancelSubscriptionReasonSwitchingApps =>
      'Me cambiaré a otra app';

  @override
  String get settingsCancelSubscriptionReasonTakingBreak =>
      'Estoy tomando un descanso del running';

  @override
  String get settingsCancelSubscriptionReasonOther => 'Otro';

  @override
  String get settingsNotNow => 'Ahora no';

  @override
  String get settingsSubscriptionCancellationInfoTitle =>
      'Administra tu suscripción en la tienda';

  @override
  String get settingsSubscriptionCancellationInfoBody =>
      'Gracias por compartir tus comentarios. Para completar la cancelación de StrivIQ Pro, administra tu suscripción en la tienda donde la compraste.';

  @override
  String get settingsSubscriptionDialogButton => 'OK';

  @override
  String get settingsIntegrations => 'Integraciones';

  @override
  String get settingsAvailableIntegrationsSection =>
      'Integraciones disponibles';

  @override
  String get settingsAppleHealth => 'Apple Health';

  @override
  String get settingsHealthConnect => 'Health Connect';

  @override
  String get settingsAccountProfileSection => 'Perfil';

  @override
  String get settingsAccountSecuritySection => 'Seguridad';

  @override
  String get settingsAccountNameLabel => 'Nombre';

  @override
  String get settingsAccountSexLabel => 'Sexo';

  @override
  String get settingsAccountNotSet => 'Sin definir';

  @override
  String get settingsAccountSecurityUnavailableTitle => 'Próximamente';

  @override
  String get settingsAccountEmailUnavailableSubtitle =>
      'Los cambios de correo estarán disponibles cuando la autenticación de la cuenta esté conectada.';

  @override
  String get settingsAccountPasswordUnavailableSubtitle =>
      'Los cambios de contraseña estarán disponibles cuando la autenticación de la cuenta esté conectada.';

  @override
  String get settingsPlanGoalsSection => 'Plan y objetivos';

  @override
  String get settingsUpdatePlanInfo => 'Actualizar plan';

  @override
  String get settingsEditGoal => 'Editar objetivo';

  @override
  String get settingsNewGoal => 'Nuevo objetivo';

  @override
  String get settingsChangeSchedule => 'Cambiar horario';

  @override
  String get settingsSummaryGoalSection => 'Objetivo';

  @override
  String get settingsSummaryTrainingSection => 'Preferencias de entrenamiento';

  @override
  String get settingsEditGoalIntroTitle =>
      'Actualiza el objetivo para el que ya estás entrenando';

  @override
  String get settingsEditGoalIntroSubtitle =>
      'Podrás revisar tu carrera, fecha, prioridad y tiempos objetivo antes de guardar los cambios.';

  @override
  String get settingsEditGoalIntroPointRace =>
      'Ajusta tu carrera o distancia objetivo.';

  @override
  String get settingsEditGoalIntroPointDate =>
      'Actualiza la fecha si tu calendario cambió.';

  @override
  String get settingsEditGoalIntroPointPriority =>
      'Revisa tu prioridad y tus tiempos antes de guardar.';

  @override
  String get settingsEditGoalIntroPointTraining =>
      'Revisa tus preferencias de entrenamiento antes de terminar la actualización.';

  @override
  String get settingsNewGoalIntroTitle =>
      'Define un objetivo completamente nuevo';

  @override
  String get settingsNewGoalIntroSubtitle =>
      'Este flujo empieza desde cero para que puedas elegir una meta distinta y guardarla para tu plan.';

  @override
  String get settingsNewGoalIntroPointRace =>
      'Elige una nueva carrera o una distancia personalizada.';

  @override
  String get settingsNewGoalIntroPointDate =>
      'Define una nueva fecha y el nuevo plazo.';

  @override
  String get settingsNewGoalIntroPointPlan =>
      'Guarda un nuevo objetivo sin cambiar aquí tu horario.';

  @override
  String get settingsNewGoalIntroPointTraining =>
      'Define las preferencias de entrenamiento que quieres usar con este objetivo.';

  @override
  String get settingsPreferencesSection => 'Preferencias';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageEnglish => 'Inglés';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageValue => 'Español';

  @override
  String get settingsUnits => 'Unidades';

  @override
  String get settingsUnitsMetric => 'Métrico (km)';

  @override
  String get settingsUnitsImperial => 'Imperial (mi)';

  @override
  String get settingsUnitsDistanceSection => 'Distancia';

  @override
  String get settingsUnitsElevationSection => 'Elevación';

  @override
  String get settingsUnitsMeters => 'Metros (m)';

  @override
  String get settingsUnitsFeet => 'Pies (ft)';

  @override
  String get settingsUnitsValue => 'Métrico (km)';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsValue => 'Activado';

  @override
  String get settingsConnectedDevicesSection => 'Dispositivos conectados';

  @override
  String get settingsGarminConnect => 'Garmin Connect';

  @override
  String get settingsConnected => 'Conectado';

  @override
  String get settingsNoConnectedDevices => 'Aun no hay dispositivos conectados';

  @override
  String get settingsLogOut => 'Cerrar sesión';

  @override
  String get settingsVersion => 'StrivIQ v1.0.0 (Build 42)';

  @override
  String get sessionDetailTitle => 'Entrenamiento';

  @override
  String get sessionDetailSessionType => 'Velocidad';

  @override
  String get sessionDetailTotalDistanceLabel => 'Distancia total';

  @override
  String get sessionDetailEstDurationLabel => 'Duración est.';

  @override
  String get sessionDetailWorkoutStructure => 'Estructura del entrenamiento';

  @override
  String get sessionDetailWarmUp => 'Calentamiento';

  @override
  String get sessionDetailWarmUpNote => 'Ritmo fácil, Zona 2';

  @override
  String get sessionDetailIntervals => 'Intervalos';

  @override
  String get sessionDetailIntervalsNote => 'Esfuerzo intenso, Zona 4';

  @override
  String get sessionDetailStrides => 'Strides';

  @override
  String get sessionDetailCoolDown => 'Enfriamiento';

  @override
  String get sessionDetailCoolDownDuration => '10 min';

  @override
  String get sessionDetailCoolDownNote => 'Ritmo fácil o caminata';

  @override
  String get sessionDetailStartWorkout => 'Iniciar entrenamiento';

  @override
  String sessionPhaseEasyRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunWarmNote =>
      'Caminata rápida + estiramientos dinámicos suaves de piernas';

  @override
  String sessionPhaseEasyRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunMainNote =>
      'Ritmo conversacional · Zona 2 · mantente relajado';

  @override
  String sessionPhaseEasyRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseEasyRunCoolNote =>
      'Caminata suave · estiramientos estáticos ligeros';

  @override
  String sessionPhaseIntervalsWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseIntervalsWarmNote =>
      'Trote suave · strides al final para activar las piernas';

  @override
  String sessionPhaseIntervalsMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String sessionPhaseIntervalsMainNote(int reps, String repDistance) {
    return '$reps × $repDistance a esfuerzo intenso · RPE 8–9';
  }

  @override
  String sessionPhaseIntervalsMainRecovery(int recoverySeconds) {
    return '$recoverySeconds s de trote suave de recuperación entre cada repetición';
  }

  @override
  String sessionPhaseStridesDuration(int reps, int seconds) {
    return '$reps × $seconds s';
  }

  @override
  String get sessionPhaseStridesNote =>
      'Rápido pero relajado · técnica suave, no es un sprint';

  @override
  String sessionPhaseStridesRecovery(int recoverySeconds) {
    return '$recoverySeconds s de caminata o trote suave entre strides';
  }

  @override
  String sessionPhaseIntervalsCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseIntervalsCoolNote =>
      'Trote suave → caminata · estiramientos completos';

  @override
  String sessionPhaseLongRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunWarmNote =>
      'Trote muy suave · comienza sin prisa';

  @override
  String sessionPhaseLongRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunMainNote =>
      'Esfuerzo constante y fácil · Zona 2 · mantente cómodo';

  @override
  String sessionPhaseLongRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseLongRunCoolNote =>
      'Caminata al final · estiramientos completos · recarga energía';

  @override
  String sessionPhaseRecoveryRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunWarmNote =>
      'Caminata suave para empezar a moverse';

  @override
  String sessionPhaseRecoveryRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunMainNote =>
      'Ritmo muy suave y conversacional · sin presión';

  @override
  String sessionPhaseRecoveryRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseRecoveryRunCoolNote =>
      'Caminata · rodillo de espuma si está disponible';

  @override
  String sessionPhaseTempoRunWarmDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunWarmNote =>
      'Trote suave · aumenta el ritmo gradualmente';

  @override
  String sessionPhaseTempoRunMainDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunMainNote =>
      'Esfuerzo cómodamente intenso · Zona 3–4';

  @override
  String sessionPhaseTempoRunCoolDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionPhaseTempoRunCoolNote =>
      'Trote suave → caminata · estiramientos completos';

  @override
  String get logSessionTitle => 'Registrar Sesión';

  @override
  String get logSessionPlannedSession => 'Sesión Planificada';

  @override
  String get logSessionSessionName => 'Intervalos Matutinos';

  @override
  String get logSessionDurationLabel => 'DURACIÓN';

  @override
  String get logSessionActiveTime => 'Tiempo activo';

  @override
  String get logSessionDistanceLabel => 'DISTANCIA';

  @override
  String get logSessionMinUnit => 'min';

  @override
  String get logSessionKmUnit => 'km';

  @override
  String get logSessionPaceValue => '7:31 / ritmo km';

  @override
  String get logSessionHowDidItFeel => '¿Cómo te fue?';

  @override
  String get logSessionEasy => 'Fácil';

  @override
  String get logSessionModerate => 'Moderado';

  @override
  String get logSessionHard => 'Duro';

  @override
  String get logSessionVeryHard => 'Muy Duro';

  @override
  String get logSessionNotes => 'Notas';

  @override
  String get logSessionOptional => '(Opcional)';

  @override
  String get logSessionNotesHint => '¿Cómo fue la carrera?';

  @override
  String get logSessionSaveButton => 'Guardar Sesión';

  @override
  String get activeRunTitle => 'Carrera Activa';

  @override
  String get activeRunDemoTracking => 'Seguimiento demo';

  @override
  String get activeRunCurrentPace => 'RITMO ACTUAL';

  @override
  String get activeRunNotificationTargetShort => 'Obj.';

  @override
  String get activeRunNotificationDistanceShort => 'Dist.';

  @override
  String get activeRunNotificationPaceShort => 'Ritmo';

  @override
  String get activeRunElapsed => 'TIEMPO';

  @override
  String get activeRunTimeUnit => 'tiempo';

  @override
  String get activeRunDistance => 'DISTANCIA';

  @override
  String get activeRunAveragePace => 'RITMO PROM.';

  @override
  String get activeRunTarget => 'OBJETIVO';

  @override
  String get activeRunPause => 'Pausar';

  @override
  String get activeRunResume => 'Reanudar';

  @override
  String get activeRunFinish => 'Finalizar';

  @override
  String activeRunPlannedSummary(
    String plannedDuration,
    String plannedDistance,
  ) {
    return '$plannedDuration · $plannedDistance';
  }

  @override
  String activeRunPlannedDuration(String plannedDuration) {
    return '$plannedDuration';
  }

  @override
  String activeRunPlannedDistance(String plannedDistance) {
    return '$plannedDistance';
  }

  @override
  String get activeRunPlannedFallback => 'Carrera guiada';

  @override
  String get activeRunGuidanceEasy =>
      'Mantén un ritmo conversacional y relajado.';

  @override
  String get activeRunGuidanceLong =>
      'Encuentra un ritmo estable y cuida el final.';

  @override
  String get activeRunGuidanceProgression =>
      'Empieza con control y aumenta el esfuerzo por fases.';

  @override
  String get activeRunGuidanceIntervals =>
      'Corre los bloques rápidos con intención y recupera bien.';

  @override
  String get activeRunGuidanceHills =>
      'Empuja en la subida y recupera al bajar.';

  @override
  String get activeRunGuidanceFartlek =>
      'Haz cambios cuando estés listo y vuelve a correr suave.';

  @override
  String get activeRunGuidanceTempo =>
      'Mantén un ritmo fuerte que puedas controlar.';

  @override
  String get activeRunGuidanceThreshold => 'Firme pero fluido. No esprintes.';

  @override
  String get activeRunGuidanceRacePace =>
      'Entra en ritmo objetivo y mantén el esfuerzo estable.';

  @override
  String get activeRunGuidanceRecovery =>
      'Debe sentirse lo bastante suave para terminar mejor.';

  @override
  String get activeRunEaseOff => 'Baja ritmo';

  @override
  String get activeRunPickUp => 'Acelera';

  @override
  String get activeRunOnTarget => 'En objetivo';

  @override
  String get activeRunPush => 'Empuja';

  @override
  String get activeRunRecover => 'Recupera';

  @override
  String get activeRunSurge => 'Cambio';

  @override
  String get activeRunEasyBlock => 'Suave';

  @override
  String get activeRunTargetFast => 'Rápido';

  @override
  String get activeRunTargetClimb => 'Subida';

  @override
  String get activeRunTargetTempo => 'Tempo';

  @override
  String get activeRunTargetThreshold => 'Umbral';

  @override
  String get activeRunTargetRace => 'Ritmo carrera';

  @override
  String get activeRunTargetEasy => 'Suave';

  @override
  String get activeRunTargetSteady => 'Estable';

  @override
  String get activeRunTargetBuild => 'Progresivo';

  @override
  String get activeRunTargetSurges => 'Cambios';

  @override
  String get activeRunTargetPaceUnit => 'ritmo';

  @override
  String get activeRunTargetEffortUnit => 'esfuerzo';

  @override
  String get activeRunHillFocusTitle => 'Enfoque de cuestas';

  @override
  String get activeRunIntervalFocusTitle => 'Enfoque de intervalos';

  @override
  String get activeRunCurrentBlock => 'Bloque actual';

  @override
  String get activeRunClimb => 'Subida';

  @override
  String get activeRunFastRep => 'Rep rápida';

  @override
  String get activeRunStride => 'Stride';

  @override
  String get activeRunRecovery => 'Recuperación';

  @override
  String get activeRunRep => 'Rep';

  @override
  String activeRunBlockRemaining(String remaining) {
    return 'quedan $remaining';
  }

  @override
  String activeRunNextBlock(String block) {
    return 'Siguiente: $block';
  }

  @override
  String get activeRunProgressionFocusTitle => 'Fases progresivas';

  @override
  String get activeRunSteadyBlock => 'Estable';

  @override
  String get activeRunStrongBlock => 'Fuerte';

  @override
  String get activeRunPaceFocusTitle => 'Control de ritmo';

  @override
  String get activeRunControl => 'Control';

  @override
  String get activeRunPaceFocusFooter =>
      'Mantente fluido dentro del rango objetivo.';

  @override
  String get activeRunLongFocusTitle => 'Enfoque de tirada larga';

  @override
  String get activeRunFocus => 'Enfoque';

  @override
  String get activeRunReminder => 'Recordatorio';

  @override
  String get activeRunFuel => 'Energía';

  @override
  String get activeRunLongFocusFooter =>
      'Bebe agua y revisa el esfuerzo antes de la próxima milla.';

  @override
  String get activeRunRecoveryFocusTitle => 'Enfoque de recuperación';

  @override
  String get activeRunEasyFocusTitle => 'Enfoque suave';

  @override
  String get activeRunRelaxed => 'Relajado';

  @override
  String get activeRunRecoveryFocusFooter =>
      'El objetivo son piernas frescas, no un parcial más rápido.';

  @override
  String get activeRunEasyFocusFooter =>
      'Deberías poder hablar en frases completas.';

  @override
  String get activeRunFartlekFocusTitle => 'Control de fartlek';

  @override
  String get activeRunEndSurge => 'Terminar cambio';

  @override
  String get activeRunStartSurge => 'Iniciar cambio';

  @override
  String get preRunTitle => 'Control Pre-carrera';

  @override
  String get preRunHeading => '¿Cómo te sientes?';

  @override
  String get preRunSubtitle =>
      'Verificación rápida para asegurarte de que la sesión de intervalos de hoy sigue siendo la decisión correcta.';

  @override
  String get preRunLegsQuestion => '¿Cómo se sienten tus piernas hoy?';

  @override
  String get preRunFresh => 'Frescas';

  @override
  String get preRunNormal => 'Normal';

  @override
  String get preRunHeavy => 'Pesadas';

  @override
  String get preRunPainQuestion => '¿Tienes algún dolor ahora mismo?';

  @override
  String get preRunNone => 'Ninguno';

  @override
  String get preRunMildDiscomfort => 'Molestia leve';

  @override
  String get preRunModeratePain => 'Dolor moderado';

  @override
  String get preRunSharpPain => 'Dolor agudo';

  @override
  String get preRunSleepQuestion => '¿Cómo fue tu sueño?';

  @override
  String get preRunGreat => 'Excelente';

  @override
  String get preRunOkay => 'Regular';

  @override
  String get preRunPoor => 'Malo';

  @override
  String get preRunReadinessQuestion => '¿Estás listo para esta sesión?';

  @override
  String get preRunLetsGo => '¡Vamos!';

  @override
  String get preRunNotFullyReady => 'No del todo listo';

  @override
  String get preRunContinue => 'Continuar';

  @override
  String get workoutOptionsTitle => 'Opciones de Entrenamiento';

  @override
  String get workoutOptionsSkipWorkout => 'Omitir Entrenamiento';

  @override
  String get workoutOptionsSkipWorkoutDescription =>
      'Elimina esta sesión del plan de esta semana';

  @override
  String get workoutOptionsRestoreWorkout => 'Restaurar Entrenamiento';

  @override
  String get workoutOptionsRestoreWorkoutDescription =>
      'Vuelve a poner esta sesión en el calendario';

  @override
  String get fullPlanTitle => 'Plan Completo';

  @override
  String get trainingHistoryTitle => 'Historial de Entrenamiento';

  @override
  String get fullPlanNote =>
      'Este es tu plan estimado completo. Puede cambiar con el tiempo según tu progreso y ajustes de entrenamiento.';

  @override
  String get fullPlanWeeksLabel => 'SEMANAS';

  @override
  String get fullPlanDistanceLabel => 'DISTANCIA';

  @override
  String get fullPlanRunsLabel => 'CARRERAS';

  @override
  String fullPlanWeekLabel(int number) {
    return 'Semana $number';
  }

  @override
  String get fullPlanCurrentBadge => 'ACTUAL';

  @override
  String get fullPlanCompletedBadge => 'HECHO';

  @override
  String get fullPlanUpcomingBadge => 'PRÓXIMA';

  @override
  String get fullPlanScheduleLabel => 'HORARIO';

  @override
  String get planNotReadyMessage => 'Tu plan está siendo preparado';

  @override
  String get planNotReadyRetry => 'Reintentar';
}
