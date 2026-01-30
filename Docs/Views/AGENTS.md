# Views Module

**Purpose:** SwiftUI user interface

## Files

| File | Role |
|------|------|
| `RecordingView.swift` | Recording controls, status display |
| `PlaybackView.swift` | Playback controls, progress |
| `OutputView.swift` | Markdown preview, export options |

## Patterns

- MVVM pattern with ObservableObject view models
- Separate view per major mode
- Sheets for settings/preferences

## Where to Start

- **New screen:** Create new file, follow existing pattern
- **Modify flow:** Update navigation in `DuckDocsApp.swift`
- **Add settings:** Add to preferences sheet

## Dependencies

- SwiftUI
- Combine (for reactive state)

## Testing

- Test UI states (recording/playing/idle)
- Test dark mode
- Test window resizing
