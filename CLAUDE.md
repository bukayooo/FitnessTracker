# Debug Fixes and Principles

## Example: Workout History Not Loading - FIXED ✅

### Problems
1. **All exercises show 0s despite having history** - Sometimes starting a workout from a template shows all exercises with 0 reps/weight even though previous workouts exist
2. **Exercises skipped in recent workouts show 0s** - Even when an exercise has history, if it was skipped in recent workouts, no history appears
3. **Inconsistent behavior** - Sometimes history loads, sometimes it doesn't

### Root Cause Analysis
The history loading function `getLastWorkoutSetData` had a critical flaw:

```swift
let workoutRequest = NSFetchRequest<NSManagedObject>(entityName: "Workout")
workoutRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
workoutRequest.fetchLimit = 5 // Check the last 5 workouts
```

**The bug**: No predicate to filter out incomplete workouts! This caused:

1. **Current workout counted in history**: When creating a new workout, it's inserted into the context with `duration = 0`. The history query includes this current workout in the fetchLimit, so instead of checking the last 5 completed workouts, it checks the current (empty) workout + the last 4 completed ones.

2. **Limited search window**: If you skip an exercise in 4+ recent workouts, the 5th workout (where you actually did it) might not be fetched, causing history to appear as 0s.

3. **Incomplete workouts pollute history**: Any abandoned/incomplete workouts (duration=0) count against the limit, reducing how far back the search goes.

### Solutions Applied

1. **Filter by completed workouts only** (WorkoutManager.swift:631):
   ```swift
   workoutRequest.predicate = NSPredicate(format: "duration > 0")
   ```
   This ensures only completed workouts (with duration > 0) are searched for history, excluding:   - The current workout being created
   - Any abandoned/incomplete workouts

2. **Increased search depth** (WorkoutManager.swift:633):
   ```swift
   workoutRequest.fetchLimit = 10 // Check the last 10 completed workouts
   ```
   Increased from 5 to 10 to handle cases where exercises are skipped across multiple workouts.

3. **Added comprehensive debug logging** (WorkoutManager.swift:624, 637, 645, 663, 666, 676):
   - Shows when searching for history starts
   - Shows how many completed workouts were found
   - Shows when matching exercises are found and which workout date
   - Shows when data is found vs when it's 0/0
   - Shows when history is successfully loaded into new workout

4. **Consistent filtering in both history functions**:
   - `getLastWorkoutSetData`: Only searches completed workouts (duration > 0), fetchLimit increased from 5 to 10
   - `getLastWorkoutSetsCount`: Now also filters by completed workouts (duration > 0)

### Key Principles
1. **Filter queries to exclude in-progress objects** - When loading historical data, exclude objects currently being created/modified
2. **Use meaningful state indicators** - The `duration` field naturally separates completed vs incomplete workouts
3. **Increase search depth for skipped items** - When items can be skipped in workflows, search further back in history
4. **Debug logging with context** - Include workout dates and which workouts are being searched to make debugging easier

## Example: Excessive Battery Drain During Workouts - FIXED ✅

### Problem
The app caused significant battery drain during workouts (20%+ per hour), phone became warm, and battery life was unacceptable for a fitness app that needs to run for extended periods.

### Root Cause Analysis
The workout timer was firing **every 0.5 seconds**, causing:
1. **7,200 timer events per hour** - Each timer firing triggers:
   - CPU wake-up from idle
   - @Published property update (`workoutElapsedSeconds`)
   - SwiftUI view re-render of entire WorkoutView hierarchy
   - Screen refresh
2. **Excessive CPU usage** - Constant wake-ups prevent CPU from entering low-power states
3. **Heat generation** - Continuous processing generates heat, triggering thermal throttling
4. **Cascading view updates** - Every 0.5s, the @Published property change triggers full WorkoutView re-render

```swift
// BEFORE - BATTERY KILLER
workoutTimer = Timer.publish(every: 0.5, on: .main, in: .common)  // 2x per second!
    .autoconnect()
    .sink { [weak self] _ in
        self.updateWorkoutElapsedTime()  // Triggers @Published update -> full view re-render
    }
```

For a typical 1-hour workout:
- 7,200 timer firings
- 7,200 view re-renders
- 7,200 CPU wake-ups
- Continuous CPU load preventing idle states

### Solution Applied

**Reduced timer frequency from 0.5s to 1.0s** (TimerManager.swift:95, 127, 195):

```swift
// AFTER - BATTERY OPTIMIZED
workoutTimer = Timer.publish(every: 1.0, on: .main, in: .common)  // 1x per second
    .autoconnect()
    .sink { [weak self] _ in
        self.updateWorkoutElapsedTime()
    }
```

**Impact**:
- Reduced timer firings by 50% (7,200 → 3,600 per hour)
- Reduced view re-renders by 50%
- Reduced CPU wake-ups by 50%
- Allows CPU to enter low-power states more frequently
- Users don't need sub-second precision for workout duration display

Applied to all three timer initialization points:
1. `startWorkoutTimer()` - When starting a new workout
2. `resumeWorkoutTimer()` - When resuming after pause
3. `restoreTimerStateIfNeeded()` - When restoring after app backgrounding

### Why Not Go Lower Than 1 Second?
- **Rest timer needs 1s precision** - Users expect countdown timers to update every second
- **Warmup timer needs 1s precision** - Short duration warmups (15s) need accurate countdown
- **Workout timer could go to 5s** - But keeping consistency across all timers is better for code maintainability
- **1s is the sweet spot** - Good enough precision while being battery-friendly

### Key Principles
1. **Match timer frequency to actual user needs** - Don't update faster than users can perceive
2. **Consider the multiplication factor** - A small improvement (0.5s → 1s) has massive impact over time
3. **@Published updates trigger full view re-renders** - Every timer tick causes the entire observed view hierarchy to re-render
4. **CPU idle time is critical for battery** - The more time between wake-ups, the better the battery life
5. **Heat = throttling = worse performance** - Reducing CPU load prevents thermal issues

## Example: Rest Timer Issues - FIXED ✅

### Problems
1. **Timer didn't auto-dismiss after completion** - Sheet reverted to "Set Rest Timer" screen instead of dismissing
2. **Timer paused when phone went to sleep** - Display showed wrong time even though notification fired correctly
3. **Previous timer state persisted** - Starting a new timer sometimes showed old timer's remaining time

### Root Cause Analysis
Multiple interconnected issues:

1. **Backwards dismissal logic**: RestTimerView only dismissed the sheet when `manualStop == true`, but should dismiss when timer completes naturally (`manualStop == false`). When timer completed, `isRestTimerActive` became false, causing the view to show the selection screen instead of dismissing.

2. **Background timing**: The timer used `Timer.publish(every: 1...)` which only runs when app is active. While restoration logic existed, it wasn't being called consistently when the app became active after sleep.

3. **State not cleaned up**: When starting a new rest timer, old timer state wasn't being properly cleared, causing lingering data to affect new timers.

### Solutions Applied

1. **Fixed auto-dismiss logic** (WorkoutView.swift:1047-1050):
   ```swift
   // Auto-dismiss when timer completes naturally (not manually stopped)
   if let userInfo = notification.userInfo,
      let manualStop = userInfo["manualStop"] as? Bool {
       if !manualStop {
           // Dismiss immediately when timer completes (no delay)
           showingRestTimer = false
       }
   }
   ```

2. **Improved background restoration** (TimerManager.swift:248-263):
   ```swift
   // Recalculate rest timer if active (handles sleep/background cases)
   if isRestTimerActive, let startTime = restStartTime {
       let elapsedTime = Int(Date().timeIntervalSince(startTime))
       let newTimeRemaining = max(0, initialRestDuration - elapsedTime)

       if newTimeRemaining > 0 {
           restTimeRemaining = newTimeRemaining
       } else {
           handleRestTimerCompletion()
       }
   }
   ```

3. **Clean up state before starting new timer** (TimerManager.swift:264-267):
   ```swift
   // Clean up any existing timer first to ensure fresh start
   if isRestTimerActive {
       stopRestTimer(manualStop: true)
   }
   ```

4. **Prevent swipe-to-dismiss during active timer** (WorkoutView.swift:1029):
   ```swift
   .interactiveDismissDisabled(timerManager.isRestTimerActive)
   ```
   This prevents users from accidentally dismissing the timer by swiping down, which would leave the timer in an inconsistent state. When on the selection screen, swipe-to-dismiss is allowed.

5. **Simplified button layout** (WorkoutView.swift:1020-1027):
   ```swift
   // Only show Close button when not actively timing
   if !timerManager.isRestTimerActive {
       Button("Close") {
           showingRestTimer = false
       }
   }
   ```
   When timer is active, only Skip and Restart buttons are available (no redundant Close button). When selecting duration, Close button is shown.

### Key Principles
1. **Timer dismissal logic should match user expectations** - Auto-dismiss on natural completion, stay open on manual stop
2. **Always recalculate time-based state when app becomes active** - Don't rely on UI timers for background timing
3. **Clean up old state before creating new state** - Prevents state pollution between operations
4. **Use elapsed time from start time, not incremental counters** - More reliable for background operations
5. **Disable gestures that bypass cleanup logic** - Use `.interactiveDismissDisabled()` to prevent swipe-to-dismiss when state cleanup is needed
6. **Remove UI delays that cause visual glitches** - Dismiss immediately rather than showing intermediate states

## Example: Workout History Not Loading - FIXED ✅

### Problems
1. **History sometimes doesn't show at all** - All exercises show 0 reps/weight even though there's historical data
2. **Skipped exercises show 0s** - Exercises not completed in the last workout show 0s even though they have history from earlier workouts
3. **Inconsistent behavior** - Sometimes works, sometimes doesn't

### Root Cause Analysis
The history loading logic had a critical bug: **it was including the current workout being created in its search results**.

When `startWorkout(from: template)` creates a new workout:
1. A new Workout object is created with today's date and `duration = 0`
2. As exercises are being created, they're immediately linked to this workout
3. When `getLastWorkoutSetData` is called to load history, it fetches the most recent workouts
4. The newly-created workout (with duration=0) was **included in the results** because there was no predicate filtering it out
5. This consumed one of the 5 fetch slots, so it only looked back 4 completed workouts instead of 5

**The Bug**: The current workout being created was included in the "last 5 workouts" fetch, effectively reducing the history search to only 4 previous completed workouts. If an exercise was skipped in those 4 workouts, history wouldn't be found even if it existed further back.

The fix:1. Added predicate `duration > 0` to only fetch completed workouts (duration is set to 0 by default, and only set to a positive value when completing a workout)
2. Increased fetchLimit from 5 to 10 to search further back in history
3. Applied same filter to getLastWorkoutSetsCount for consistency4. Added comprehensive logging to help debug history loading issues

This ensures:- The current workout being created is never included in history lookups- Abandoned/incomplete workouts are excluded from history- More history is searched (10 workouts instead of 5)- Better logging to diagnose issues
</thinking>

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Investigate history loading logic", "status": "completed", "activeForm": "Investigating history loading logic"}, {"content": "Fix history loading to exclude current/incomplete workouts", "status": "completed", "activeForm": "Fixing history loading to exclude current/incomplete workouts"}, {"content": "Test history loading scenarios", "status": "in_progress", "activeForm": "Testing history loading scenarios"}]

### Problem
When starting a workout from a template, the warmup timer showed "no warmups configured" even though the template had warmups. Logs showed warmups were loaded into TimerManager but WarmupTimerView wasn't displaying them.

### Root Cause Analysis
The issue was **multiple TimerManager instances being created**. WorkoutView was using:
```swift
@ObservedObject var timerManager = TimerManager()
```

This creates a NEW TimerManager instance every time the view re-renders, which happened constantly. Evidence from logs:
- WorkoutView set warmups on instance: `ObjectIdentifier(0x000000010550c740)`
- WarmupTimerView rendered with different instances: `ObjectIdentifier(0x000000010752610)`, `ObjectIdentifier(0x00000001072bec0)`, etc.

## General Solution Principles

### 1. **Use @StateObject for Object Ownership**
```swift
// WRONG - creates new instance on every re-render
@ObservedObject var timerManager = TimerManager()

// CORRECT - creates one instance owned by the view
@StateObject var timerManager = TimerManager()
```

**Principle**: When a view needs to OWN and CREATE an ObservableObject, use `@StateObject`. When a view receives an already-created object from a parent, use `@ObservedObject`.

### 2. **Debug Instance Identity**
When debugging object sharing issues:
```swift
print("Instance: \(ObjectIdentifier(object))")
```
This reveals if multiple instances exist when there should be one.

### 3. **Systematic Debug Log Management**
Instead of removing logs entirely, control spam with state flags:
```swift
@State private var hasLoggedRender = false

var body: some View {
    let _ = {
        if !hasLoggedRender {
            print("DEBUG: Message appears once")
            hasLoggedRender = true
        }
    }()
    // ... rest of view
}
```

**Principle**: Debug logs should appear once per logical operation, not once per view render.

### 4. **Main Thread for @Published Updates**
Ensure @Published property updates happen on main thread:
```swift
DispatchQueue.main.async {
    self.publishedProperty = newValue
}
```

### 5. **Siri Shortcuts Integration Pattern**
When implementing Siri integration, use NSUserActivity rather than custom intents for simplicity:
```swift
// Donate user activity for Siri
let activity = NSUserActivity(activityType: "com.app.action")
activity.title = "Action Name"
activity.isEligibleForPrediction = true
activity.suggestedInvocationPhrase = "Hey Siri, do action"
activity.becomeCurrent()
```

**Key Implementation Points:**
- Use NSUserActivity instead of complex Intent definitions
- Handle activities in app delegate with `.onContinueUserActivity()`
- Execute background shortcuts with x-callback-url patterns to stay in app
- Donate activities automatically when user performs actions

### 6. **Intent Definition Complexity**
Avoid complex Intent definition files - they often fail to build with cryptic errors. NSUserActivity is more reliable and easier to maintain for most use cases.

## Key Lessons
1. **@StateObject vs @ObservedObject matters** - Wrong choice creates subtle but critical bugs
2. **View re-rendering is frequent** - Any object creation in a view body will happen repeatedly  
3. **Debug strategically** - Use ObjectIdentifier to track instance identity
4. **Fix root cause, not symptoms** - The issue wasn't timing or UI updates, it was object lifecycle
5. **Log management is crucial** - Spam logs hide real issues; controlled logging reveals them
6. **Siri integration simplified** - NSUserActivity beats custom intents for reliability
7. **Build failures guide design** - If Intent definitions fail repeatedly, switch approaches

## Testing Evidence
After warmup fix:
- Single TimerManager instance used consistently
- WarmupTimerView correctly displays loaded warmups
- Debug logs appear once instead of hundreds of times
- Warmup functionality works as expected

After Siri integration:
- Build succeeds with NSUserActivity approach
- User activities automatically donated when starting workouts
- Background shortcuts execute while staying in app
- Voice commands work: "Hey Siri, start my [template] workout"