import { createClient } from '@supabase/supabase-js';
import { generatePlanFromProfile } from './openai.ts';
import { buildWorkoutSteps } from './workout-steps.ts';

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // User-scoped client — respects RLS
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const body = await req.json().catch(() => ({}));
  const requestedBy: string = body.requestedBy ?? 'onboarding';

  // 1. Fetch runner profile for the authenticated user
  const { data: profileRow, error: profileError } = await supabase
    .from('runner_profiles')
    .select('data')
    .eq('user_id', user.id)
    .maybeSingle();

  if (profileError || !profileRow) {
    return new Response(
      JSON.stringify({ error: 'Runner profile not found' }),
      { status: 404, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const profileData = profileRow.data as Record<string, unknown>;

  // 2. Read guidance preference from profile
  const guidanceType = (profileData.guidancePreference as string ?? 'effort') as
    'effort' | 'pace' | 'heartRate';

  // 3. Call OpenAI with structured output
  let generatedPlan;
  try {
    generatedPlan = await generatePlanFromProfile(profileData);
  } catch (err) {
    console.error('OpenAI generation failed:', err);
    return new Response(
      JSON.stringify({ error: 'Plan generation failed', detail: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // 4. Build workout steps deterministically for each session
  const sessionsWithSteps = generatedPlan.sessions.map((session) => ({
    ...session,
    workoutSteps: buildWorkoutSteps(session, guidanceType),
  }));

  const planJson = {
    ...generatedPlan,
    sessions: sessionsWithSteps,
  };

  // 5-6. Service-role client — bypasses RLS for writes
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Deactivate previous active plans
  await adminClient
    .from('plan_versions')
    .update({ is_active: false })
    .eq('user_id', user.id)
    .eq('is_active', true);

  // 7. Insert new active plan version
  const versionId = crypto.randomUUID();
  const { error: insertError } = await adminClient.from('plan_versions').insert({
    id: versionId,
    user_id: user.id,
    generated_at: new Date().toISOString(),
    requested_by: requestedBy,
    is_active: true,
    schema_version: 1,
    data: planJson,
  });

  if (insertError) {
    console.error('Failed to save plan version:', insertError);
    return new Response(
      JSON.stringify({ error: 'Failed to save plan', detail: insertError.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(JSON.stringify({ versionId, plan: planJson }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
