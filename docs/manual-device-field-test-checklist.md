# Sprint 6, Task 6.3: Manual Device Field Test Checklist

## Test Environment Setup

**Devices Required:**
- iOS device (physical, not simulator)
- Android device (physical, not emulator)

**Pre-conditions:**
- App installed from latest build
- Location permissions granted
- Battery charged > 80% (to observe drain)
- Watch battery level before and after test

**Test Route:**
- 200m short walk: use a known measured route (track, measured path)
- 20-30 min run: use GPS watch or map to establish ground truth distance

---

## Test 1: Outdoor 200m Short Walk

### Objective
Verify distance accuracy on a short, known distance.

### Steps
1. Find a measured 200m route (athletic track straightaway, measured path)
2. Open RunFlow app
3. Start a run session
4. Walk the 200m route at normal pace
5. End the run

### Expected Results
- Distance recorded: **190m - 210m** (within ~5%)
- Route shows path approximation (not just straight line)
- GPS status shows `ready` throughout
- Duration matches walking time (~2-4 min)

### Pass / Fail
- [ ] Pass / [ ] Fail
- Actual distance recorded: _______
- Notes: ___________________________________

---

## Test 2: 20-30 Minute Run/Walk

### Objective
Verify stable GPS tracking over extended activity and confirm battery drain is acceptable.

### Steps
1. Start a 20-30 minute run (or run/walk) session outdoors
2. Run at varied paces (slow, medium, fast)
3. Include walking intervals if planned
4. Keep screen on for first 2 minutes, then background the app
5. Observe battery before and after

### Expected Results
- Distance within ~3-5% of actual route
- Average pace displayed matches expected
- GPS status stays `ready` or `weak` (not `lost`) for > 95% of time
- Battery drain: < 15% for 30 min active GPS run
- Splits recorded correctly (if applicable)
- Route points show continuous path

### Pass / Fail
- [ ] Pass / [ ] Fail
- Actual distance: _______ (ground truth from watch/GPS)
- App recorded distance: _______
- Variance: _______%
- Battery before: _______%
- Battery after: _______%
- Notes: ___________________________________

---

## Test 3: Background App for 5 Minutes During Active Run

### Objective
Confirm GPS tracking continues when app is backgrounded.

### Steps
1. Start a run session
2. After GPS locks (`ready`), background the app
3. Run/walk for 5 minutes
4. Reopen the app
5. Verify distance and route have been recorded

### Expected Results
- Distance has continued accumulating while backgrounded
- Route shows points from the background period
- No crashes or permission prompts on resume
- GPS status still showing valid

### Pass / Fail
- [ ] Pass / [ ] Fail
- Distance before backgrounding: _______
- Distance after reopening: _______
- Additional distance recorded: _______
- Notes: ___________________________________

---

## Test 4: Kill / Reopen Mid-Run (Cold Restore)

### Objective
Verify active run state is restored correctly after app kill.

### Steps
1. Start a run session
2. Run for 2-3 minutes to accumulate some distance
3. Force-kill the app (swipe away / terminate)
4. Reopen the RunFlow app
5. Verify the run is still active and distance/time have been restored

### Expected Results
- App reopens to active run screen (not home)
- Elapsed time is accurate (no large gaps)
- Distance is preserved (no large jump on resume)
- No crash on cold restore

### Pass / Fail
- [ ] Pass / [ ] Fail
- Time before kill: _______ min
- Time after reopen: _______ min
- Distance before kill: _______ km
- Distance after reopen: _______ km
- Notes: ___________________________________

---

## Test 5: Disable Location Mid-Distance Block

### Objective
Confirm the app handles location being disabled mid-run gracefully.

### Steps
1. Start a run session with a distance-based block
2. Wait for GPS to lock to `ready`
3. Run for 1-2 minutes
4. **iOS**: Go to Settings > Privacy > Location Services > disable for RunFlow
   **Android**: Go to Settings > Location > disable location OR pull down quick settings and disable location
5. Observe UI response for 30-60 seconds
6. Re-enable location
7. Observe recovery behavior

### Expected Results
- GPS status changes to `lost` promptly
- If distance-based block: modal appears with wait/end options (non-dismissible)
- If duration-based block: dismissible warning appears
- **No crash** when permissions change
- When location re-enabled: GPS status recovers to `ready` or `weak`
- Distance resumes accumulating correctly after re-enable (no large jump)

### Pass / Fail
- [ ] Pass / [ ] Fail
- GPS status change detected: [ ] Yes / [ ] No
- Modal appeared correctly: [ ] Yes / [ ] No / [ ] N/A (duration block)
- Crash occurred: [ ] Yes / [ ] No
- Recovery successful: [ ] Yes / [ ] No
- Notes: ___________________________________

---

## Test 6: Permission Denied / Service Disabled at Start

### Objective
Confirm pre-run permission flows work on physical devices.

### Steps
1. Start a run session with distance blocks (requires GPS)
2. Deny location permission when prompted
3. Confirm GPS-required dialog appears
4. End run attempt
5. Start a run session with duration-only blocks
6. Confirm timer-only mode activates without GPS

### Expected Results
- GPS-denied distance-block workout shows GPS-required dialog and does not start
- GPS-denied duration-only run enters timer-only mode
- "Open Settings" button navigates to app settings
- "Enable Location Services" navigates to location settings

### Pass / Fail
- [ ] Pass / [ ] Fail
- Notes: ___________________________________

---

## Acceptance Criteria Summary

| Criteria | Target | Observed | Pass |
|----------|--------|----------|------|
| Distance accuracy (200m walk) | ±5% | _______ | [ ] |
| Distance accuracy (20-30 min run) | ±5% | _______ | [ ] |
| Battery drain (30 min run) | < 15% | _______% | [ ] |
| No crash on permission change | 0 crashes | _______ | [ ] |
| Background tracking works | 5+ min ok | _______ min | [ ] |
| Cold restore works | no jump/drift | _______ | [ ] |

---

## Device Info (fill in per test)

| Field | iOS Device | Android Device |
|-------|------------|----------------|
| Model | | |
| OS Version | | |
| App Version | | |
| Location Permission | | |
| Background App Refresh | | |

---

## Testers

| Person | Device | Date | Signature |
|--------|--------|------|-----------|
| | iOS | | |
| | Android | | |

---

## Notes / Bugs Found

1. ___________________________________
2. ___________________________________
3. ___________________________________

---

*Checklist version: Sprint 6 Task 6.3 - 2026-04-25*