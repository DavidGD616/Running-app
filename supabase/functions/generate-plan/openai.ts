import OpenAI from "openai";
import { type GeneratedPlan, GeneratedPlanSchema } from "./schema.ts";

export async function generatePlanFromProfile(
  profileData: Record<string, unknown>,
): Promise<GeneratedPlan> {
  const client = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY")! });

  const systemPrompt = `You are an expert running coach. Generate a personalized
training plan based on the runner profile provided. Be specific and progressive.
This app is phone-first. Use effort-based guidance, duration, distance, and
plain coaching cues; do not rely on heart-rate zones, power, cadence, or
watch-only metrics. Adapt workout difficulty, volume, workout type, and
progression to the runner's experience level, fitness history, health
constraints, schedule, and goal.

Treat schedule.hardDays as days the runner prefers not to train. Avoid placing
long runs, intervals, hills, tempo, threshold, race-pace, fartlek, progression,
or other high-stress sessions on those days. If the schedule is constrained, use
hardDays only for rest, recovery, short easy running, or optional cross-training.
Do not move a fixed goal race date just because it falls on a hardDay.
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

Always anchor week 1 sessions starting from the nearest upcoming Monday. Ensure
a proper taper in the final 2 weeks before the race.`;

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
            totalWeeks: { type: "integer", minimum: 4, maximum: 26 },
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
                      "crossTraining",
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
