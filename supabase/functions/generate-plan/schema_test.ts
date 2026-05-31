import { strict as assert } from "node:assert";
import { GeneratedPlanSchema } from "./schema.ts";

Deno.test("GeneratedPlanSchema accepts 3-week plans", () => {
  const parsed = GeneratedPlanSchema.parse({
    totalWeeks: 3,
    raceType: "fiveK",
    sessions: [],
  });

  assert.equal(parsed.totalWeeks, 3);
});
