# Playback Module

**Purpose:** Replay recorded actions and capture screenshots

## Files

| File | Role |
|------|------|
| `ActionPlayer.swift` | Action replay engine, timing control |
| `ScreenCapture.swift` | ScreenCaptureKit screenshot capture |

## Key Concepts

### Action Replay
- Uses `CGEvent.post()` to simulate user actions
- Maintains timing between actions (respects delays)
- Coordinates must match original display

### Screen Capture
- ScreenCaptureKit (SCStream) for screenshots
- Captures after each action completes
- Supports full display, window, or region

## Where to Start

- **Change replay speed:** `ActionPlayer.swift` (timing multiplier)
- **Modify capture area:** `ScreenCapture.swift` (SCContentFilter)
- **Add capture trigger:** `ActionPlayer.swift` → call `ScreenCapture.capture()`

## Dependencies

- CoreGraphics (CGEvent posting)
- ScreenCaptureKit (screenshots)

## Testing

- Test on multiple displays
- Test with missing target apps
- Test capture quality settings
