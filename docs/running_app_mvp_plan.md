# Running App MVP Plan

## Overview

This MVP is focused on building the smallest useful version of a native mobile running app that can generate a personalized training plan for users training for a race such as a 5K, 10K, half marathon, or marathon.

The app will be built with **Flutter** for **iOS and Android** and must support **Spanish and English** from the beginning.

The first version should prioritize:
- a clean onboarding flow
- personalized plan generation
- a simple weekly training view
- basic run logging
- support for users with and without a watch
- a clear foundation for future adaptive training logic

The goal of the MVP is not to build the smartest running app possible. The goal is to build the first version that is useful, coherent, and realistic to ship.

---

## MVP goal

Build an app that can:

1. onboard a user
2. understand their running goal and current fitness
3. generate a basic personalized training plan
4. show that plan clearly in the app
5. let the user log completed runs
6. use simple logic to adjust the next week when needed

---

## Target users for MVP

### Primary users
- beginner runners training for their first race
- recreational runners who want structure
- runners training 2 to 5 days per week

### Secondary users
- experienced runners who want a simple race plan
- runners with a watch who want pace or heart-rate guidance

### Not the focus for MVP
- elite runners
- highly advanced coaching logic
- deep smartwatch analytics
- social features
- complex community features

---

## Core MVP features

## 1. Authentication

### Scope
- Email and password sign up
- Log in
- Log out
- Forgot password

### Notes
- Keep auth simple
- Social login can come later

---

## 2. Account creation

### Purpose
Collect essential account-level preferences and basic profile data immediately after sign up and before the full onboarding flow begins.

### Fields
- Preferred units
  - Miles
  - Kilometers

- Gender
  - Male
  - Female
  - Non-binary
  - Prefer not to say

- Birthday
  - Native date picker

### Why this should happen before onboarding
- Preferred units affect how distances and pace are shown throughout onboarding
- Birthday can help with age-aware plan decisions and profile setup
- Gender can be collected if the product wants it for profile completeness or future training analysis, but it should not be required for generating the first useful plan unless there is a clear product reason

### MVP recommendation
- Put this section immediately after sign up and before the full running onboarding flow
- Keep it short and fast
- Make only preferred units and birthday required if needed by the product
- Consider making gender optional

### UI notes
- Present this as a short setup step, not a heavy form
- Use large segmented controls for unit selection
- Use a native date picker for birthday
- Keep the copy simple and welcoming
- Add a short explanation for why the app asks for this information only if needed

---

## 3. Onboarding flow

### Purpose
Collect the minimum data needed to generate a training plan.

### Sections
1. Goal
2. Current fitness
3. Schedule
4. Health and injury
5. Training preferences
6. Watch and device setup
7. Recovery and lifestyle
8. Motivation and adherence
9. Summary

### MVP requirement
- User must complete onboarding before generating first plan
- All onboarding content must support Spanish and English
- The app should store onboarding answers in a normalized profile object

---

## 4. Runner profile

### Purpose
Create a structured profile the plan engine can use.

### Core profile data
- goal race
- goal type
- race date
- current experience level
- weekly running frequency
- weekly running volume
- longest recent run
- can run 10 minutes continuously
- can complete goal distance
- training days available
- preferred long run day
- weekday and weekend availability
- injury status
- plan preference
- preferred guidance mode
- watch connected or not
- watch type
- selected metrics
- sleep
- stress
- job activity level
- preferred coaching tone
- language
- preferred units
- gender
- birthday

---

## 5. Plan generation engine

### Purpose
Generate the user’s first personalized training plan.

### MVP approach
Use a **rule-based plan generator**, not AI-first planning.

### MVP responsibilities
- classify the user
- choose the right plan template
- set initial weekly structure
- assign run types
- choose guidance mode
- generate the first block of training

### Runner classifications for MVP
- new runner
- beginner
- intermediate
- experienced

### Plan goal types for MVP
- finish
- improve time
- build consistency
- general fitness

### Basic templates for MVP
- beginner run/walk
- beginner finish plan
- intermediate finish plan
- intermediate improvement plan
- experienced improvement plan

### Weekly structures for MVP
- 2-day plan
- 3-day plan
- 4-day plan
- 5-day plan

### Session types for MVP
- easy run
- walk/run
- long run
- steady run
- tempo
- intervals
- recovery run
- rest day
- optional strength day

### Guidance modes for MVP
- effort
- pace
- heart rate
- time only

---

## 6. Plan display

### Purpose
Show the training plan clearly inside the app.

### Main views
- current week view
- upcoming runs list
- session detail screen
- simple plan overview screen

### Each session should show
- day
- session type
- duration or distance
- target guidance
- short notes
- completion status

### Example weekly structure
- Tuesday: easy run
- Thursday: tempo
- Saturday: long run

### MVP notes
- Make this view very clear and calm
- Avoid too much data at once
- Make the next run obvious

---

## 7. Run logging

### Purpose
Allow the user to complete and record sessions.

### MVP logging options
- mark workout as completed
- enter duration
- enter distance
- enter effort
- optional notes

### If watch is not connected
User can log manually.

### If watch is connected
For MVP, this can be one of two approaches:
- Phase 1: still manual entry, even with watch selected
- Phase 2: import basic run data

### Completion states
- completed
- partially completed
- skipped
- moved to another day

---

## 8. Basic adaptation logic

### Purpose
Make the app feel responsive after the user starts training.

### MVP adaptation decisions
- progress
- maintain
- reduce
- restructure

### Signals used in MVP
- completed runs
- skipped runs
- self-reported effort
- optional soreness or fatigue check

### MVP rule examples
- if the user completes the week well, next week progresses slightly
- if the user skips key runs, next week stays similar or reduces
- if the user reports pain or very high fatigue, reduce training load

### Important note
This logic should stay simple and explainable in MVP.

---

## 9. Pre-run check-in

### Purpose
Quickly understand readiness before a run.

### MVP version
Keep it very short.

### Easy-day check-in
- How do you feel today?
- Any pain right now?

### Workout or long-run check-in
- How do your legs feel?
- Any pain right now?
- How was your sleep?
- Do you feel ready for this session?

### MVP result
The app can:
- keep session as planned
- shorten session
- lower intensity
- suggest rest or easy movement

---

## 10. Settings

### MVP settings
- language selection: Spanish / English
- units: miles / kilometers
- training guidance preference
- notification preferences
- edit onboarding answers

---

## 11. Notifications

### MVP notifications
- reminder for today’s run
- reminder to complete onboarding
- reminder to log a completed session
- weekly summary reminder

### Notes
- Keep notifications useful, not spammy

---

## MVP screens

## Auth
- Splash screen
- Sign up
- Log in
- Forgot password

## Onboarding
- Welcome
- Account Creation
- Goal
- Current fitness
- Schedule
- Health and injury
- Training preferences
- Watch and device setup
- Recovery and lifestyle
- Motivation and adherence
- Summary

## App core
- Home / Today
- Weekly plan
- Session details
- Log run
- Progress summary
- Settings

---

## Home screen MVP

### Purpose
Give the user one clear place to start.

### Show
- today’s session or next session
- short readiness prompt
- weekly progress summary
- quick actions

### Quick actions
- start today’s session
- mark complete
- log run manually
- view full week

---

## Progress screen MVP

### Purpose
Show simple progress without overcomplicating the app.

### Show
- runs completed this week
- streak or consistency count
- weekly volume trend
- long run progress
- recent completed sessions

### Avoid in MVP
- advanced race prediction
- complex VO2 max interpretation
- deep recovery analytics

---

## Watch integration plan

### MVP phase
The onboarding should support watch selection from day one, but full integration does not need to be complete in version one.

### Recommended rollout
#### Phase 1
- user selects whether they have a watch
- user selects watch type
- app uses that preference only for guidance mode and future readiness
- run logging stays manual

#### Phase 2
- connect device account
- import basic run data such as distance, duration, and heart rate

### Important
Do not block the MVP waiting for full watch integration.

---

## Technical architecture for MVP

## Frontend
- Flutter
- iOS and Android support
- localization from the beginning

## Suggested app layers
- presentation layer
- application/state layer
- domain layer
- data layer

## Suggested state areas
- auth state
- onboarding state
- user profile state
- training plan state
- workout logging state
- settings state

## Backend needs
- authentication
- user profile storage
- onboarding answers storage
- training plan generation endpoint or service
- workout completion storage
- settings storage

---

## Suggested data models

## User
- id
- email
- language
- units
- gender
- birthday
- createdAt

## RunnerProfile
- userId
- goalRace
- goalType
- raceDate
- experienceLevel
- weeklyRuns
- weeklyVolume
- longestRun
- canRun10Minutes
- canCompleteGoalDistance
- trainingDaysAvailable
- preferredLongRunDay
- weekdayAvailability
- weekendAvailability
- injuryStatus
- injuryHistory
- healthCondition
- planPreference
- guidancePreference
- watchConnected
- watchType
- watchMetrics
- sleepHours
- stressLevel
- activityLevel
- coachingTone

## TrainingPlan
- id
- userId
- templateId
- startDate
- currentWeek
- status

## TrainingSession
- id
- planId
- weekNumber
- day
- type
- duration
- distance
- guidanceMode
- targetData
- notes
- priority

## WorkoutLog
- id
- sessionId
- completed
- durationActual
- distanceActual
- effortActual
- notes
- loggedAt

---

## Localization requirements

The app must support:
- Spanish
- English

### MVP localization scope
- onboarding copy
- labels
- button text
- errors and validation
- plan labels
- session types
- settings
- notifications

### Notes
- Design copy to work naturally in both languages
- Avoid text that becomes awkward when translated

---

## What should not be in MVP

Do not include these in version one:
- social feed
- friend system
- advanced coach chat
- deep AI planning engine
- advanced wearables analytics
- nutrition tracking
- route mapping
- live GPS tracking
- in-run audio coaching
- community challenges
- advanced premium monetization

These can come later.

---

## Recommended development phases

## Phase 1: foundation
- project setup in Flutter
- localization setup
- auth
- onboarding UI
- profile storage

## Phase 2: planning core
- runner classification
- rule-based plan generator
- plan templates
- weekly plan display

## Phase 3: training flow
- session detail screen
- run logging
- completion states
- basic progress screen

## Phase 4: simple adaptation
- pre-run check-in
- progress / maintain / reduce / restructure logic
- basic weekly refresh

## Phase 5: polish
- notifications
- settings
- copy refinement in Spanish and English
- bug fixes
- improved empty states and loading states

---

## Success criteria for MVP

The MVP is successful if a user can:
- sign up
- complete onboarding
- generate a personalized training plan
- understand what to run this week
- log completed sessions
- feel that the app adapts in a basic but useful way

The MVP is also successful if the app feels:
- clear
- stable
- motivating
- fast
- useful without needing a watch

---

## Final recommendation

Build the MVP around clarity and consistency, not complexity.

The strongest first version is one that does a few things very well:
- understands the runner
- gives a believable plan
- shows what to do next
- makes it easy to log progress
- adjusts with simple and trustworthy rules

That is enough to create a strong foundation for future features such as deeper watch integration, smarter adaptation, and more advanced performance analytics.

