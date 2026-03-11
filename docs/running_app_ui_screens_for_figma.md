# Running App Account Creation and Onboarding UI Screens for Figma

This document focuses only on the account creation and onboarding screens that should be designed first in Figma.

The goal is to define the minimum UI flow needed before the main app experience starts.

The app is a native mobile app built with Flutter for iOS and Android and supports Spanish and English.

---

## Design goals

The screens should feel:
- clean
- athletic
- modern
- motivating
- easy to scan
- fast to use on mobile

The UI should avoid feeling cluttered or overly technical.

---

## Global UI direction

### Visual style
- Dark mode first
- Clean typography
- Strong spacing
- Large tap targets
- Rounded cards
- Clear hierarchy
- Minimal but polished visuals

### Core components to design first
- Top navigation bar
- Progress indicator
- Primary button
- Secondary button
- Choice cards
- Chips / segmented controls
- Input fields
- Date picker trigger
- Time picker input
- Bottom sheet
- Modal
- Empty state
- Loading state
- Success state
- Session card
- Weekly calendar card

---

# 1. Auth screens

## 1.1 Splash screen
### Purpose
First branded loading screen when the app opens.

### Elements
- App logo
- App name
- Simple loading state

---

## 1.2 Welcome screen
### Purpose
Entry point before sign up or log in.

### Elements
- Headline
- Short value proposition
- Primary CTA: Create account
- Secondary CTA: Log in
- Language visibility if needed

---

## 1.3 Sign up screen
### Purpose
Create a new account.

### Elements
- Email field
- Password field
- Confirm password field
- Create account button
- Link to log in
- Terms/privacy text

---

## 1.4 Log in screen
### Purpose
Sign in to existing account.

### Elements
- Email field
- Password field
- Log in button
- Forgot password link
- Link to create account

---

## 1.5 Forgot password screen
### Purpose
Password recovery.

### Elements
- Email field
- Reset password button
- Confirmation message state

---

# 2. Account creation screens

## 2.1 Account setup screen
### Purpose
Collect basic account-level preferences before full onboarding.

### Elements
- Preferred units selector
  - Miles
  - Kilometers
- Gender selector
- Birthday picker
- Continue button

### UI notes
- Keep it short and welcoming
- Use large segmented controls for units
- Use a native-feeling date input

---

# 3. Onboarding screens

The onboarding flow should be designed as a small set of full screens, where each screen contains one section of related questions instead of splitting every single question into its own screen.

The goal is to keep the onboarding efficient, realistic, and easier to design in Figma.

## 3.1 Onboarding intro screen
### Purpose
Introduce the setup flow.

### Elements
- Title
- Short explanation
- Progress context
- CTA: Start

---

## 3.2 Goal screen
### Purpose
Collect all goal-related information in one screen.

### Elements
- Race type cards
  - 5K
  - 10K
  - Half Marathon
  - Marathon
  - Other
- Do you have a race date?
  - Yes / No
- Date picker if Yes
- Goal type cards
  - Just finish
  - Finish feeling strong
  - Improve my time
  - Build consistency
  - General fitness
- Current race time input if relevant
- Target race time input if relevant
- Continue button

### UI notes
- Use progressive disclosure inside the same screen
- Hide time inputs unless the selected goal needs them
- Keep the layout scrollable but visually grouped

---

## 3.3 Current fitness screen
### Purpose
Collect current running ability and recent history in one screen.

### Elements
- Experience level
- Current running days per week
- Average weekly running volume
- Longest recent run
- Can run 10 minutes continuously?
- Can complete goal distance?
- Previous race experience
- Optional benchmark input
- Continue button

### UI notes
- Group related selectors into stacked sections
- Keep optional benchmark collapsed or visually secondary

---

## 3.4 Schedule screen
### Purpose
Collect all schedule and availability information in one screen.

### Elements
- Training days available per week
- Preferred long run day
- Weekday availability
- Weekend availability
- Hard-to-train days
- Preferred run time of day
- Continue button

### UI notes
- Use chips for day selection
- Make preferred long run day stand out clearly

---

## 3.5 Health and injury screen
### Purpose
Collect health, injury, and risk preference information in one screen.

### Elements
- Current pain or injury
- Pain location if relevant
- Injury history
- Health conditions affecting exercise
- Plan preference
  - Safest possible
  - Balanced
  - Performance-focused
- Continue button

### UI notes
- Use conditional reveal for pain location
- Show short inline caution text only when needed

---

## 3.6 Training preferences screen
### Purpose
Collect the user’s preferred training style in one screen.

### Elements
- Preferred guidance mode
- Speed workouts preference
- Strength training preference
- Running surface
- Terrain
- Walk/run preference
- Continue button

### UI notes
- Use icons where useful for surfaces
- Keep the layout clean and modular

---

## 3.7 Watch and device setup screen
### Purpose
Collect all watch and device-related choices in one screen.

### Elements
- Do you use a watch or running device?
- Watch type if Yes
- Device data usage preference
- Metrics to use
- Heart-rate zone preference
- Pace recommendation preference
- Adaptive plan preference from watch data
- No-watch guidance option if no device is connected
- Continue button

### UI notes
- This screen should use progressive disclosure heavily
- If the user selects No device, hide watch-specific inputs and show only no-watch guidance
- Make device options easy to scan with branded rows or icons

---

## 3.8 Recovery and lifestyle screen
### Purpose
Collect recovery capacity and day-to-day life load in one screen.

### Elements
- Sleep on weekdays
- Work/activity level
- Stress level
- Day-to-day recovery feeling
- Continue button

---

## 3.9 Motivation and adherence screen
### Purpose
Collect motivational and behavioral inputs in one screen.

### Elements
- Main reason for running
- Biggest obstacle to consistency
- Confidence level
- Preferred coaching tone
- Continue button

---

## 3.10 Onboarding summary screen
### Purpose
Review everything before generating the plan.

### Elements
- Summary cards
- Edit actions
- CTA: Build my plan

---

## 3.11 Plan generation screen
### Purpose
Short loading / transition screen.

### Elements
- Progress or loading animation
- Messaging like creating your plan

---

# 4. Figma organization recommendation

## Page 1
- Foundations
  - colors
  - typography
  - spacing
  - iconography

## Page 2
- Components
  - buttons
  - cards
  - chips
  - inputs
  - selectors
  - progress bars
  - navigation

## Page 3
- Auth screens

## Page 4
- Account creation + onboarding screens

## Page 5
- States
  - loading
  - empty
  - error
  - success

---

# 9. Priority screens for first design pass

Only focus on these screens first:

1. Splash screen
2. Welcome screen
3. Sign up screen
4. Log in screen
5. Forgot password screen
6. Account setup screen
7. Onboarding intro screen
8. Goal screen
9. Current fitness screen
10. Schedule screen
11. Health and injury screen
12. Training preferences screen
13. Watch and device setup screen
14. Recovery and lifestyle screen
15. Motivation and adherence screen
16. Onboarding summary screen
17. Plan generation screen

---

# 10. Final design note

The goal of the UI is not just to look good. The screens should make the app feel simple, motivating, and trustworthy. Every screen should help the runner quickly understand what to do next, what matters right now, and how they are progressing.

