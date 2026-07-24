import { createClient } from "@supabase/supabase-js";

import {
  createNewGoalHandler,
  createProductionDependencies,
} from "./handler.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const publicClient = createClient(
  supabaseUrl,
  requireEnv("SB_PUBLISHABLE_KEY"),
);
const adminClient = createClient(
  supabaseUrl,
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
);

Deno.serve(createNewGoalHandler(
  createProductionDependencies(publicClient, adminClient),
));
