# Claude Rules

Don't use never your sign or your message of "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" or similar

## MCP Tools

Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Localization (ARB files)

Never hardcode dynamic values (numbers, distances, durations, counts) directly in ARB string values. Use Flutter's ARB placeholder system instead so the text template is fixed in translations and the actual values come from session/model data at runtime.

Example:
```json
"sessionPhaseIntervalsMainNote": "{reps} × {repDistance} at hard effort · RPE 8–9",
"@sessionPhaseIntervalsMainNote": {
  "placeholders": {
    "reps": { "type": "int" },
    "repDistance": { "type": "String" }
  }
}
```

After editing any ARB file, run `flutter gen-l10n` from `apps/mobile/` to regenerate the `.dart` l10n files. Never edit the generated files by hand.
