import {
  buildCandidatePlan,
  type BuildCandidatePlanInput,
  type CandidatePlan,
} from "./candidate-builder.ts";

Deno.test("candidate builder is importable without starting an HTTP server", () => {
  const builder: (
    input: BuildCandidatePlanInput,
  ) => Promise<Response | CandidatePlan> = buildCandidatePlan;

  if (typeof builder !== "function") {
    throw new Error("Expected buildCandidatePlan to be an importable function");
  }
});
