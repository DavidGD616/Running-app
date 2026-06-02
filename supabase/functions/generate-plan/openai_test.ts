import { strict as assert } from "node:assert";
import { resolveOpenAiModel } from "./openai.ts";

Deno.test("resolveOpenAiModel uses default when OPENAI_MODEL is unset", () => {
  const model = resolveOpenAiModel(undefined);
  assert.equal(model, "gpt-5.4-mini");
});

Deno.test("resolveOpenAiModel accepts trimmed configured model", () => {
  const model = resolveOpenAiModel("  gpt-5.4  ");
  assert.equal(model, "gpt-5.4");
});

Deno.test("resolveOpenAiModel fails fast for empty configured model", () => {
  assert.throws(
    () => resolveOpenAiModel("   "),
    Error,
    "OPENAI_MODEL is set but empty",
  );
});

Deno.test("resolveOpenAiModel fails fast for whitespace in configured model", () => {
  assert.throws(
    () => resolveOpenAiModel("gpt 5.4"),
    Error,
    "OPENAI_MODEL is invalid",
  );
});
