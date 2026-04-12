import OpenAI from 'openai';
import { GeneratedPlanSchema, type GeneratedPlan } from './schema.ts';

export async function generatePlanFromProfile(
  profileData: Record<string, unknown>,
): Promise<GeneratedPlan> {
  const client = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY')! });

  const systemPrompt = `You are an expert running coach. Generate a personalized
training plan based on the runner profile provided. Be specific and progressive.
Assign realistic distances and durations. For easy and long runs use targetZone easy
or longRun. For intervals provide intervalReps, intervalRepDistanceMeters, and
intervalRecoverySeconds. For tempo runs use targetZone tempo with warmUpMinutes and
coolDownMinutes. Always anchor week 1 sessions starting from the nearest upcoming
Monday. Ensure a proper taper in the final 2 weeks before the race.`;

  const userPrompt = `Runner profile:\n${JSON.stringify(profileData, null, 2)}

Generate a complete personalized training plan. Return only the JSON matching the schema exactly.`;

  const completion = await client.chat.completions.create({
    model: 'gpt-5.4-mini',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    response_format: {
      type: 'json_schema',
      json_schema: {
        name: 'training_plan',
        strict: true,
        schema: {
          type: 'object',
          properties: {
            totalWeeks: { type: 'integer', minimum: 4, maximum: 26 },
            raceType: { type: 'string', enum: ['fiveK', 'tenK', 'halfMarathon', 'marathon', 'other'] },
            sessions: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  id: { type: 'string' },
                  date: { type: 'string' },
                  weekNumber: { type: 'integer' },
                  type: { type: 'string', enum: ['easyRun','longRun','progressionRun','intervals','hillRepeats','fartlek','tempoRun','thresholdRun','racePaceRun','recoveryRun','crossTraining','restDay'] },
                  distanceKm: { type: ['number', 'null'] },
                  durationMinutes: { type: ['integer', 'null'] },
                  coachNote: { type: ['string', 'null'] },
                  targetZone: { type: ['string', 'null'], enum: ['recovery','easy','steady','tempo','threshold','interval','racePace','longRun', null] },
                  warmUpMinutes: { type: ['integer', 'null'] },
                  coolDownMinutes: { type: ['integer', 'null'] },
                  intervalReps: { type: ['integer', 'null'] },
                  intervalRepDistanceMeters: { type: ['integer', 'null'] },
                  intervalRecoverySeconds: { type: ['integer', 'null'] },
                },
                required: ['id','date','weekNumber','type','distanceKm','durationMinutes','coachNote','targetZone','warmUpMinutes','coolDownMinutes','intervalReps','intervalRepDistanceMeters','intervalRecoverySeconds'],
                additionalProperties: false,
              },
            },
          },
          required: ['totalWeeks', 'raceType', 'sessions'],
          additionalProperties: false,
        },
      },
    },
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) throw new Error('OpenAI returned no content');

  const raw = JSON.parse(content);
  return GeneratedPlanSchema.parse(raw);
}
