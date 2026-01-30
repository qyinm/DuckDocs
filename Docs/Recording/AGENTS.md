# Recording Module

**Purpose:** Capture user actions via CGEvent monitoring

## Files

| File | Role |
|------|------|
| `ActionRecorder.swift` | Main coordinator, state management |
| `EventMonitor.swift` | CGEvent tap implementation |
| `ActionSequence.swift` | Data models (Action enum, structs) |

## Key Concepts

### CGEvent Tap
- Creates global event monitor for mouse/keyboard
- Runs on background thread
- Must handle permission denial gracefully

### Action Types
```swift
enum Action {
    case click(x, y, type)
    case drag(from, to)
    case scroll(direction, amount)
    case delay(seconds)
}
```

## Where to Start

- **New action type:** Start in `ActionSequence.swift` → add to enum, then implement in `EventMonitor.swift` → handle in `ActionPlayer.swift`
- **Modify capture:** `EventMonitor.swift` (event filtering)
- **State changes:** `ActionRecorder.swift` (start/stop/pause)

## Dependencies

- CoreGraphics (CGEvent)
- No external dependencies

## Testing

- Test permission denied flow
- Test coordinate accuracy across displays
- Test event filtering (ignore system events)
