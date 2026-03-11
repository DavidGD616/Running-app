# Running App Onboarding Sections

Use this document as a product spec for the onboarding flow of a native mobile running app built with Flutter. The app must support both Spanish and English.

The onboarding should collect the minimum high-value information needed to generate a personalized running plan. It must work for both complete beginners and experienced runners trying to improve performance.

The experience should feel native-mobile, fast, modern, and low-friction. The app will be built with Flutter for iOS and Android.

---

## Product goals

The onboarding must help the app:

- understand the user’s goal
- understand the user’s current running ability
- understand schedule constraints
- understand injury and recovery risk
- understand how the user prefers to train
- understand whether the user has a watch or device connected
- choose the correct training guidance mode:
  - effort
  - pace
  - heart rate
  - hybrid
- generate the correct training template

The onboarding must not feel like a giant form.

---

## UX principles

- Native mobile layout first
- One main question per screen when possible
- Use grouped screens only when the fields are tightly related
- Use large tap targets instead of dense dropdowns when possible
- Show progress at the top
- Keep helper text short and useful
- Use progressive disclosure so advanced questions only appear when needed
- Autosave answers as the user moves through the flow
- Keep the visual design calm, modern, and performance-oriented
- Optimize everything for thumb reach and quick completion

---

## Visual style direction

### App feel
- Clean and athletic
- Premium but simple
- Dark mode by default, with strong contrast and clean spacing
- Minimal clutter
- Focus on clarity and momentum

### Suggested UI patterns
- Native app onboarding screens
- Top navigation with back button and progress indicator
- Bottom-aligned primary CTA sized for thumb reach
- Section title and short description at the top of each screen
- Large tappable choice cards for primary options
- Segmented controls for short option sets
- Wheel pickers or native pickers for time/date where appropriate
- Inline validation instead of disruptive alerts
- Smooth transitions between screens

---

## Onboarding structure

### 1. Goal

#### Purpose
Understand what the user is training for and what outcome they want.

#### Fields
- Goal race
  - 5K
  - 10K
  - Half Marathon
  - Marathon
  - Other

- Has race date
  - Yes
  - No

- Race date
  - Native date picker
  - Only show if user selects Yes

- Goal type
  - Just finish
  - Finish feeling strong
  - Improve my time
  - Build consistency
  - General fitness

- If goal type is Improve my time
  - Current race time
  - Target race time

#### UI notes
- Make the race options feel like large selection cards with icon + label
- Keep the date picker native to iOS/Android feel
- If the user selects Improve my time, reveal the time inputs below with smooth animation

---

### 2. Current fitness

#### Purpose
Understand where the user is starting from.

#### Fields
- Running experience
  - Brand new
  - Beginner
  - Intermediate
  - Experienced

- Current running days per week
  - 0
  - 1
  - 2
  - 3
  - 4
  - 5+

- Average weekly running volume
  - 0 miles
  - 1–5 miles
  - 6–10 miles
  - 11–15 miles
  - 16–20 miles
  - 21–30 miles
  - 31+

- Longest recent run
  - I have not done one
  - Less than 3 miles
  - 3–5 miles
  - 6–8 miles
  - 9–10 miles
  - 11–13 miles
  - 13+

- Can you currently run continuously for 10 minutes?
  - Yes
  - No

- Can you currently complete your goal distance?
  - Yes
  - No
  - Not sure

- Have you done this race distance before?
  - Never
  - Once
  - 2–3 times
  - 4+

- Optional benchmark
  - 1-mile run time
  - 1-mile walk time
  - 5K time
  - 10K time
  - Half marathon time
  - Skip for now

#### UI notes
- Use compact stacked cards with large tap zones
- For time input, use native time-style numeric entry or wheel picker
- Keep optional benchmark clearly labeled as optional

---

### 3. Schedule

#### Purpose
Understand when the user can realistically train.

#### Fields
- Training days per week available
  - 2
  - 3
  - 4
  - 5
  - 6
  - 7

- Preferred long run day
  - Monday
  - Tuesday
  - Wednesday
  - Thursday
  - Friday
  - Saturday
  - Sunday

- Weekday time available
  - 20 min
  - 30 min
  - 45 min
  - 60 min
  - 75+ min

- Weekend time available
  - 30 min
  - 45 min
  - 60 min
  - 90 min
  - 2+ hours

- Days that are hard to train
  - Monday
  - Tuesday
  - Wednesday
  - Thursday
  - Friday
  - Saturday
  - Sunday

- Preferred time of day
  - Early morning
  - Morning
  - Afternoon
  - Evening
  - No preference

#### UI notes
- Use chip selectors for days of the week
- Make the long run day selection visually distinct because it is a major plan anchor
- Keep the schedule screens simple and fast to tap through

---

### 4. Health and injury

#### Purpose
Understand limitations and risk.

#### Fields
- Current pain or injury
  - No
  - Yes, mild
  - Yes, moderate
  - Yes, severe

- If yes, where?
  - Foot
  - Ankle
  - Calf
  - Shin
  - Knee
  - Hamstring
  - Hip
  - Back
  - Other

- Running-related injury in the last 12 months
  - No
  - Yes, once
  - Yes, multiple times

- Health conditions affecting exercise
  - No
  - Yes

- Plan preference
  - Safest possible
  - Balanced
  - Performance-focused

#### UI notes
- Use caution colors only when needed, not everywhere
- If the user selects moderate or severe pain, show a short safety note inline
- Keep this section calm and reassuring, not alarming

---

### 5. Training preferences

#### Purpose
Understand how the user wants to train.

#### Fields
- Preferred guidance mode
  - Effort
  - Pace
  - Heart rate
  - Decide for me

- Want speed workouts included?
  - Yes
  - No
  - Only if needed

- Strength training included?
  - No
  - 1 day per week
  - 2 days per week
  - 3 days per week

- Where do you run most?
  - Road
  - Treadmill
  - Track
  - Trail
  - Mixed

- Terrain
  - Flat
  - Some hills
  - Hilly
  - Mixed

- Walk/run intervals
  - Yes
  - No
  - Only if needed

#### UI notes
- Keep this section feeling customizable without overwhelming the user
- Use icons where useful, especially for road, trail, treadmill, and track

---

### 6. Watch and device setup

#### Purpose
Understand what data sources are available and how the plan can be guided.

#### Fields
- Do you use a watch or running device?
  - Yes
  - No

- If yes, which device?
  - Garmin
  - Apple Watch
  - COROS
  - Polar
  - Suunto
  - Fitbit
  - Other

- How should the app use your device data?
  - Import runs automatically
  - Use heart rate only
  - Use pace and distance only
  - Use all available data
  - I am not sure

- Should the plan use watch-based metrics when available?
  - Yes
  - No
  - Only for heart rate

- Which metrics do you want to use?
  - Heart rate
  - Heart rate zones
  - Pace
  - Distance
  - Cadence
  - Elevation
  - Training load
  - Recovery time
  - None

- Heart-rate-based training zones?
  - Yes
  - No
  - Only if supported

- Pace recommendations based on watch data?
  - Yes
  - No

- Should the app adjust the plan from watch data?
  - Yes, automatically
  - Yes, but ask me first
  - No, keep my plan fixed

- If no device is connected, how should the app guide training?
  - Effort only
  - Time-based runs
  - Simple beginner guidance
  - Decide for me

#### UI notes
- This should be its own section, not buried inside general preferences
- If device connection is supported in onboarding, add a clear Connect Device button
- If connection is skipped, reassure the user that the app can still work without a watch
- Show device logos or simple branded rows for faster recognition

---

### 7. Recovery and lifestyle

#### Purpose
Understand how much training stress the user can realistically recover from.

#### Fields
- Average sleep on weekdays
  - Less than 5
  - 5–6
  - 6–7
  - 7–8
  - 8+

- Work/activity level
  - Mostly desk
  - Mixed
  - Physical job

- Average stress level
  - Low
  - Moderate
  - High

- Day-to-day recovery
  - Usually fresh
  - Sometimes tired
  - Often tired
  - Always tired

#### UI notes
- Keep this section lightweight and quick
- Avoid making it feel medical or overly analytical

---

### 8. Motivation and adherence

#### Purpose
Understand why the user is doing this and what might prevent consistency.

#### Fields
- Why are you doing this?
  - Personal challenge
  - Health
  - Weight loss
  - Improve performance
  - Race with friends/family
  - Build discipline
  - Other

- What gets in the way of consistency?
  - Time
  - Motivation
  - Fatigue
  - Stress
  - Pain or soreness
  - Boredom
  - I do not know how to train
  - Other

- Confidence level
  - 1 to 10 scale

- Preferred coaching tone
  - Simple and direct
  - Encouraging
  - Detailed and data-driven
  - Strict and performance-focused

#### UI notes
- Use a slider or pill-style scale for confidence
- This section should feel personal but fast

---

### 9. Summary

#### Purpose
Show the user what the app understood before generating the plan.

#### Show
- Goal race
- Race date
- Goal type
- Current level
- Weekly running baseline
- Available training days
- Preferred long run day
- Guidance mode
- Device connected or not
- Plan style

#### Actions
- Build my plan
- Edit answers

#### UI notes
- Present the summary as a clean checklist or stacked cards
- Make the final CTA strong and motivating
- Add a small loading state after tapping Build my plan, followed by a plan generation screen

---

## Mobile app behavior notes

### Navigation
- Use standard native navigation patterns
- Allow the user to go back without losing answers
- Preserve state if the app is backgrounded briefly

### Validation
- Use inline validation
- Do not block progress unless the field is truly required
- Distinguish clearly between required and optional inputs

### Performance
- Screens should feel instant
- Avoid heavy animations
- Keep interactions responsive and smooth

### Accessibility
- Large text support
- Good color contrast
- Large touch targets
- Labels always visible
- Do not rely only on color to communicate state

### Tone of copy
- Clear
- Confident
- Simple
- Performance-oriented without sounding aggressive
- Natural in both Spanish and English, not just directly translated word-for-word

---

## Recommended screen order

1. Goal
2. Current fitness
3. Schedule
4. Health and injury
5. Training preferences
6. Watch and device setup
7. Recovery and lifestyle
8. Motivation and adherence
9. Summary

---

## Flutter implementation note

The app will be built with Flutter for iOS and Android. The onboarding should be designed with native-mobile interaction patterns in mind, while remaining practical to implement with Flutter widgets, state management, and platform integrations such as device connection flows.

### Localization and language support
- Support both Spanish and English across the full onboarding flow
- All UI copy, labels, helper text, validation, and summaries must be fully localized
- The language system should be planned from the beginning, not added later
- Keep button labels, option text, and helper copy concise in both languages
- Avoid text that only works naturally in one language
- Support language-aware formatting for dates, times, and units when appropriate
- Make it easy to add more languages later

### Flutter UI guidance
- Use platform-appropriate behavior where it improves the experience
- Keep components reusable across onboarding screens
- Prefer smooth, lightweight transitions
- Design cards, selectors, chips, and progress components as reusable Flutter widgets
- Make date/time pickers feel appropriate for each platform
- Keep layouts responsive across different phone sizes

## Final implementation note

The watch and device setup is a core section because it changes how the app prescribes training. If the user has no watch, the app should lean on effort and time. If the user has heart rate data, the app can support heart-rate-based guidance. If the user has richer device data, the app can support more adaptive behavior. The onboarding should make this feel helpful, not technical.

