import OpenAI from "openai";
import { type GeneratedPlan, GeneratedPlanSchema } from "./schema.ts";

export async function generatePlanFromProfile(
  profileData: Record<string, unknown>,
  locale: "en" | "es" = "en",
  expectedTotalWeeks: number | null = null,
): Promise<GeneratedPlan> {
  const client = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY")! });
  const coachNoteLanguage = locale === "es" ? "Spanish" : "English";
  const goal = typeof profileData.goal === "object" && profileData.goal != null
    ? profileData.goal as Record<string, unknown>
    : {};
  const hasRaceDate = typeof goal.raceDate === "string" &&
    goal.raceDate.length > 0;
  const raceInstruction = hasRaceDate
    ? "When a fixed race date is given, the goal race is the final session and the plan ends exactly on race day — generate no sessions after it. Keep the last 2–3 days before the race easy or rest (no intervals, tempo, or long runs in that window)."
    : "The runner has no fixed race date. Build toward a final goal-distance race/test in the last week; do not create a short fake race.";
  const totalWeeksInstruction = expectedTotalWeeks == null
    ? ""
    : `\nThe fixed race date requires exactly ${expectedTotalWeeks} plan weeks. Return totalWeeks=${expectedTotalWeeks}, include at least one session for every weekNumber 1 through ${expectedTotalWeeks}, and place the fixed goal race in weekNumber ${expectedTotalWeeks}.`;

  const systemPrompt = `You are an expert running coach. Generate a personalized
training plan based on the runner profile provided. Be specific and progressive.
This app is phone-first. Use effort-based guidance, duration, distance, and
plain coaching cues; do not rely on heart-rate zones, power, cadence, or
watch-only metrics. Adapt workout difficulty, volume, workout type, and
progression to the runner's experience level, fitness history, health
constraints, schedule, and goal.

If profileData.fitness.athleteSummary is present, treat it as measured training
history and prefer it over self-reported fitness when they conflict. Anchor
week-1 total volume around athleteSummary.weeklyVolumeKm with a conservative
distribution across the selected training days. Use
athleteSummary.acuteChronicRatio to cap weekly ramp and avoid aggressive
increases; when the athlete is already building, keep growth generally <=10%.
Use athleteSummary.longestRecentRunKm to size easy and long-run distances and
avoid sudden long-run jumps. Use derived paces
(typicalEasyPaceSecPerKm, typicalHardPaceSecPerKm,
estimatedThresholdPaceSecPerKm) as effort context only. Keep coach notes in
effort-based, mobile-readable language.
If athleteSummary.insufficientData is true, treat athleteSummary as a weak
signal and do not override self-reported fitness with it.

If athleteSummary is absent, keep current no-Strava behavior and rely on the
existing profile fields only.

Write every coachNote in ${coachNoteLanguage}. Keep JSON field names, enum
values, targetZone values, and all structured data keys exactly as defined in
the schema. coachNote is display text only; never rely on it for app logic.

Treat schedule.hardDays as days the runner finds hard to train. These are
unavailable or prefer-rest days, not hard-workout days. If schedule.trainingDays
can be satisfied using non-hard days, schedule restDay on every hardDay. If the
selected schedule is too constrained and a hardDay must be used, use only
easyRun or recoveryRun there. Never place longRun, intervals, hills, tempo,
threshold, race-pace, fartlek, progression, or other high-stress sessions on a
hardDay. Do not move a fixed goal race date just because it falls on a hardDay.
The app supports run and rest sessions in this flow; do not suggest unsupported
mobility, strength, or cross-training activities in coachNote text.
Honor schedule.trainingDays as the target number of training days per week.
Use restDay sessions for the remaining days when returning full calendar weeks.

Assign realistic distances and durations. For easy and long runs use targetZone
easy or longRun. For intervals provide intervalReps, intervalRepDistanceMeters,
and intervalRecoverySeconds. For tempo runs use targetZone tempo with
warmUpMinutes and coolDownMinutes. Use strides when appropriate for the runner's
level and goal. Strides are short fast-but-relaxed efforts, not sprints. Place
them inside easy or recovery runs, usually after the easy portion and before the
cooldown. Never place strides on long runs, hard workout days, hardDays, or race
week. Prefer non-consecutive stride days and early/mid-week easy days. Use
4-8 reps of 15-30 seconds at 85-95% effort with 60-90 seconds full easy
walk/jog recovery. For intermediate runners, use 4 x 20 seconds with 90 seconds
recovery, 1-2 sessions per week when the schedule has safe easy days. For
experienced runners, use 6 x 20 seconds with 80-90 seconds recovery, 2 sessions
per week when safe. For brand-new or beginner runners, use 0-1 sessions per
week, if used, with 4 x 15 seconds and 90 seconds recovery.

Structure the plan using race-prep phases:
base, build, specific, peak, taperRace.

Base: easy aerobic running, routine, and gradual long-run habit.
Build: increase weekly load and introduce controlled quality.
Specific: use race-relevant workouts and long-run development.
Peak: highest useful workload, including the peak long run.
TaperRace: reduce volume, keep light sharpness, and prepare for race/test day.

The first planned training session should be easyRun or recoveryRun unless it is
a fixed goal race date. Introduce quality sessions only after the runner has at
least one controlled easy/base session in the plan.

Always anchor week 1 sessions starting from the Monday of the current week.
${raceInstruction}${totalWeeksInstruction}`;

  const userPrompt = `Runner profile:\n${JSON.stringify(profileData, null, 2)}

Generate a complete personalized training plan. Return only the JSON matching the schema exactly.`;

  const completion = await client.chat.completions.create({
    model: "gpt-5.4-mini",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "training_plan",
        strict: true,
        schema: {
          type: "object",
          properties: {
            totalWeeks: { type: "integer", minimum: 3, maximum: 26 },
            raceType: {
              type: "string",
              enum: ["fiveK", "tenK", "halfMarathon", "marathon", "other"],
            },
            sessions: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  id: { type: "string" },
                  date: { type: "string" },
                  weekNumber: { type: "integer" },
                  type: {
                    type: "string",
                    enum: [
                      "easyRun",
                      "longRun",
                      "progressionRun",
                      "intervals",
                      "hillRepeats",
                      "fartlek",
                      "tempoRun",
                      "thresholdRun",
                      "racePaceRun",
                      "recoveryRun",
                      "restDay",
                    ],
                  },
                  distanceKm: { type: ["number", "null"] },
                  durationMinutes: { type: ["integer", "null"] },
                  coachNote: { type: ["string", "null"] },
                  targetZone: {
                    type: ["string", "null"],
                    enum: [
                      "recovery",
                      "easy",
                      "steady",
                      "tempo",
                      "threshold",
                      "interval",
                      "racePace",
                      "longRun",
                      null,
                    ],
                  },
                  warmUpMinutes: { type: ["integer", "null"] },
                  coolDownMinutes: { type: ["integer", "null"] },
                  intervalReps: { type: ["integer", "null"] },
                  intervalRepDistanceMeters: { type: ["integer", "null"] },
                  intervalRecoverySeconds: { type: ["integer", "null"] },
                  strideReps: { type: ["integer", "null"] },
                  strideSeconds: { type: ["integer", "null"] },
                  strideRecoverySeconds: { type: ["integer", "null"] },
                },
                required: [
                  "id",
                  "date",
                  "weekNumber",
                  "type",
                  "distanceKm",
                  "durationMinutes",
                  "coachNote",
                  "targetZone",
                  "warmUpMinutes",
                  "coolDownMinutes",
                  "intervalReps",
                  "intervalRepDistanceMeters",
                  "intervalRecoverySeconds",
                  "strideReps",
                  "strideSeconds",
                  "strideRecoverySeconds",
                ],
                additionalProperties: false,
              },
            },
          },
          required: ["totalWeeks", "raceType", "sessions"],
          additionalProperties: false,
        },
      },
    },
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) throw new Error("OpenAI returned no content");

  const raw = JSON.parse(content);
  return GeneratedPlanSchema.parse(raw);
}
