# Audio Stutter After Deep Sleep Resume - Analysis

## Problem Description
- **Symptom**: Audio stutters for less than a second after resuming from deep sleep
- **Scope**: Only affects libretro cores, NOT native Linux games or PortMaster games
- **Timing**: Occurs **a few seconds after resume** (not immediately), then returns to normal

## Root Cause Analysis

### 1. **Audio System Reset During Resume**

**Location**: `workspace/all/common/api.c:3773-3775`
```c
// reinitialize audio after sleep otherwise it doesnt come back on sometimes
LOG_info("Reinitialize audio after sleep\n");
SND_resetAudio(snd.sample_rate_in, snd.frame_rate);
```

**What `SND_resetAudio()` does** (`api.c:2707-2711`):
```c
void SND_resetAudio(double sample_rate, double frame_rate)
{
	SND_quit();  // Closes SDL audio device, frees buffer
	SND_init(sample_rate, frame_rate);  // Reinitializes with empty buffer, starts paused
}
```

**Impact**:
- SDL audio device is completely closed and reopened
- Audio buffer is freed and reallocated (empty)
- Audio starts in **paused state** and waits for 60% buffer fill before unpausing

### 2. **Resampler State Persistence Issue**

**Location**: `workspace/all/common/api.c:2192-2206`
```c
static SRC_STATE *src_state = NULL;  // Static - persists across resets!

if (!src_state || resetSrcState)
{
	resetSrcState = 0;
	src_state = src_new(soundQuality, 2, &error);
	// ...
}
```

**Problem**:
- The resampler state (`src_state`) is **static** and persists across `SND_resetAudio()`
- When audio buffer is cleared but resampler state remains, there's a **discontinuity**
- The resampler has internal history/filter state that doesn't match the new empty buffer
- This causes audio artifacts (stuttering) until the resampler state stabilizes

### 3. **Core Continues Running During Sleep**

**Location**: `workspace/all/minarch/minarch.c:7173`
```c
while (!quit) {
	core.run();  // Core continues running even during sleep
	// ...
}
```

**What happens during sleep**:
- `PWR_enterSleep()` only pauses audio output (`SND_pauseAudio(true)`)
- The libretro core **continues running** and generating audio samples
- Audio callbacks (`audio_sample_batch_callback`) are still called
- Samples are sent to `SND_batchSamples()` but audio device is paused

**Location**: `workspace/all/minarch/minarch.c:4784-4794`
```c
static size_t audio_sample_batch_callback(const int16_t *data, size_t frames) { 
	if (!fast_forward || ff_audio) {
		if (use_core_fps || fast_forward) {
			return SND_batchSamples_fixed_rate((const SND_Frame*)data, frames);
		}
		else {
			return SND_batchSamples((const SND_Frame*)data, frames);
		}
	}
	else return frames;
};
```

### 4. **Buffer Fill Delay After Resume**

**Location**: `workspace/all/common/api.c:2389-2394` and `2508-2513`
```c
// let audio buffer fill a little first and then unpause audio so no underruns occur
if (currentbufferfree < snd.frame_count * 0.6f) {
	SND_pauseAudio(false);  // Unpause when 60% full
} else if (currentbufferfree > snd.frame_count * 0.99f) {
	SND_pauseAudio(true);   // Pause when >99% full
}
```

**Impact**:
- After `SND_resetAudio()`, buffer is empty
- Audio stays paused until buffer reaches 60% fill
- During this time, the core is generating audio but it's not playing
- This creates a **gap** in audio playback

### 5. **Rolling Average State Loss - DELAYED STUTTER CAUSE**

**Location**: `workspace/all/common/api.c:2288-2345`
```c
#define ROLLING_AVERAGE_WINDOW_SIZE 120
static float adjustment_history[ROLLING_AVERAGE_WINDOW_SIZE] = {0.0f};
static float remaining_space_history[ROLLING_AVERAGE_WINDOW_SIZE] = {0.0f};
```

**Critical Timing Issue**:
- These are **static arrays that persist across resets**
- After `SND_resetAudio()`, the history contains **stale data from before sleep**
- The rolling average window is **120 samples**
- At 60fps, that's **120 frames = ~2 seconds**
- **Timeline after resume**:
  1. **0-2 seconds**: History contains mix of stale (pre-sleep) and new (post-resume) data
  2. **~2 seconds**: History window is fully replaced with new data
  3. **At transition point**: Rolling average calculation changes significantly
  4. **Result**: Sudden timing adjustment causes audible stutter

**How it works** (`api.c:2338-2345`):
```c
// Calculate the rolling average
float rolling_average = 0.0f;
for (int i = 0; i < ROLLING_AVERAGE_WINDOW_SIZE; ++i)
{
    rolling_average += adjustment_history[i];  // Mix of stale + new data
}
rolling_average /= ROLLING_AVERAGE_WINDOW_SIZE;
return rolling_average;  // Used to adjust audio timing ratio
```

**Why the delay**:
- The stale data from before sleep represents a different buffer state
- As new data gradually replaces it, the average slowly shifts
- When the window is fully replaced (~2 seconds), the average **suddenly jumps** to reflect only post-resume state
- This sudden change in `bufferadjustment` (used in `api.c:2423`) causes the resampling ratio to change abruptly
- The abrupt ratio change causes the stutter

**Timeline Visualization**:
```
Time 0s (Resume):     [Stale Data] [Stale Data] ... [Stale Data]  (120 samples, all stale)
Time 0.5s:            [New Data] [Stale Data] ... [Stale Data]   (1 new, 119 stale)
Time 1.0s:            [New Data] [New Data] ... [Stale Data]     (60 new, 60 stale)
Time 1.5s:            [New Data] [New Data] ... [Stale Data]     (90 new, 30 stale)
Time 2.0s:            [New Data] [New Data] ... [New Data]       (120 new, 0 stale) ← STUTTER HERE
Time 2.5s+:           [New Data] [New Data] ... [New Data]       (all new, stable)
```

The stutter occurs when the last stale sample is replaced, causing the rolling average to suddenly reflect only the post-resume state.

## Why Only Libretro Cores?

1. **Native games/PortMaster**: 
   - Likely pause their audio generation during sleep
   - Or handle audio resume differently (may not reset audio system)
   - May use different audio APIs that handle suspend/resume better

2. **Libretro cores**:
   - Run continuously via `core.run()` loop
   - Don't know about sleep state
   - Audio callbacks are called from core's execution context
   - No mechanism to pause core execution during sleep

## Possible Solutions (Analysis Only)

### Solution 1: Reset Resampler State on Audio Reset
**Location**: `api.c:2707-2711`
- Add `resetSrcState = 1;` before `SND_quit()` in `SND_resetAudio()`
- This would force resampler to reinitialize with clean state
- **Risk**: May cause brief audio discontinuity, but should be cleaner

### Solution 2: Preserve Audio Buffer State
**Location**: `api.c:2707-2711`
- Instead of `SND_quit()` + `SND_init()`, use `SDL_PauseAudioDevice()` only
- Keep buffer and resampler state intact
- **Risk**: SDL audio device may not recover properly from suspend

### Solution 3: Pre-fill Buffer Before Unpausing
**Location**: `api.c:3773-3775` and `api.c:2389-2394`
- After `SND_resetAudio()`, wait for buffer to fill before returning from `PWR_exitSleep()`
- Or lower the 60% threshold temporarily after resume
- **Risk**: May delay resume slightly

### Solution 4: Clear Rolling Average History
**Location**: `api.c:2707-2711`
- Reset `adjustment_history` and `remaining_space_history` arrays in `SND_resetAudio()`
- Prevents stale data from affecting buffer timing
- **Risk**: Low, but may cause brief timing instability

### Solution 5: Pause Core Execution During Sleep
**Location**: `api.c:3717-3744` and `minarch.c:7170-7205`
- Add mechanism to pause `core.run()` during sleep
- Resume core execution after audio is ready
- **Risk**: Complex, may break save states, requires core coordination

### Solution 6: Use SDL Audio Resume Instead of Reset
**Location**: `api.c:3773-3775`
- Try `SDL_PauseAudioDevice(device_id, 0)` instead of full reset
- Only reset if that fails
- **Risk**: May not work if SDL audio device is in bad state after suspend

## Most Likely Root Cause (Updated for Delayed Stutter)

**Primary**: **Rolling average history transition** - Stale data from before sleep persists in the 120-sample window. After ~2 seconds, when the window is fully replaced with new data, the rolling average calculation suddenly changes, causing an abrupt timing adjustment that manifests as stutter.

**Secondary**: Resampler state persistence - The static `src_state` persists across `SND_resetAudio()`, creating a discontinuity between old resampler state and new empty buffer.

**Tertiary**: Buffer fill delay (60% threshold) - Not the main cause since stutter is delayed, but contributes to initial instability.

## Recommended Investigation Order (Updated)

**Given the delayed timing (~2 seconds), the rolling average history is the most likely culprit:**

1. **Solution 4 (HIGHEST PRIORITY)**: Clear rolling average history in `SND_resetAudio()`
   - Reset `adjustment_history[]` and `remaining_space_history[]` arrays
   - Reset `adjustment_index` and `remaining_space_index` to 0
   - This prevents stale pre-sleep data from affecting post-resume timing
   - **Expected**: Should eliminate the ~2 second delayed stutter

2. **Solution 1**: Reset resampler state on audio reset
   - Set `resetSrcState = 1` before `SND_quit()` in `SND_resetAudio()`
   - Ensures clean resampler state after resume

3. **Solution 2**: Consider preserving buffer state if SDL allows
   - Only if Solution 4 doesn't fully resolve the issue
   - May help with initial stability

4. **Solution 3**: Pre-fill buffer before unpausing
   - Lower priority since stutter is delayed, not immediate

## Code Locations Summary

- **Sleep entry**: `workspace/all/common/api.c:3717-3744` (`PWR_enterSleep`)
- **Sleep exit**: `workspace/all/common/api.c:3745-3778` (`PWR_exitSleep`)
- **Audio reset**: `workspace/all/common/api.c:2707-2711` (`SND_resetAudio`)
- **Audio init**: `workspace/all/common/api.c:2595-2676` (`SND_init`)
- **Resampler**: `workspace/all/common/api.c:2185-2286` (`resample_audio`)
- **Buffer fill logic**: `workspace/all/common/api.c:2389-2394`, `2508-2513`
- **Core execution**: `workspace/all/minarch/minarch.c:7170-7205` (main loop)
- **Audio callback**: `workspace/all/minarch/minarch.c:4784-4794`

