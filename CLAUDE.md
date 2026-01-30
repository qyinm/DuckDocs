# DuckDocs - Context for AI Assistants

**Project:** DuckDocs
**Type:** macOS Native App (Swift/SwiftUI)
**Domain:** Automation + AI Document Generation

---

## What This Project Does

DuckDocs automates the creation of documentation by capturing screens and converting them to markdown:

1. **Select**: Choose capture target (full screen, region, or specific window)
2. **Configure**: Set "next" action (arrow key, space, etc.) and capture count
3. **Auto-Capture**: Automatically performs action → captures screenshot → repeats
4. **Generate**: Sends screenshots to OpenRouter API (Vision LLM) for markdown conversion

**User Journey:** Configure → Start Capture → Auto Action/Capture Loop → AI Processing (parallel) → Markdown Output

---

## When Working on This Project

### If Adding Capture Features
- Look at: `DuckDocs/Playback/`
- Key files: `AutoCaptureService.swift`, `ScreenCapture.swift`
- Must handle: Capture modes (fullScreen, region, window), SCStream configuration

### If Adding AI Features
- Look at: `DuckDocs/AI/`
- Key files: `DeepSeekOCRService.swift`
- Must handle: OpenRouter API, image base64 encoding, parallel processing

### If Working on UI
- Look at: `DuckDocs/Views/`
- Key files: `ContentView.swift`, `RegionSelectorWindow.swift`, `WindowPickerView.swift`
- Pattern: SwiftUI with @Observable

### If Adding Capture Selection
- `RegionSelectorWindow.swift`: NSPanel overlay for drag-to-select region
- `WindowPickerView.swift`: SwiftUI sheet for window selection
- `CaptureSettings.swift`: CaptureMode enum (fullScreen, region, window)

---

## Critical Technical Details

### ScreenCaptureKit
```swift
// Modern screenshot API (macOS 12.3+)
let content = try await SCShareableContent.current
let filter = SCContentFilter(display: display, excludingWindows: [])
// Supports: captureScreen(), captureRegion(rect), captureWindowByID(id)
```
- Supports window capture, display capture, or region capture
- Must handle stream lifecycle (start/stop properly)

### OpenRouter API Integration
```swift
// Vision LLM API call
let requestBody: [String: Any] = [
    "model": "openai/gpt-4.1-nano",
    "max_tokens": 4096,
    "messages": [[
        "role": "user",
        "content": [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
        ]
    ]]
]
```

**API Details:**
- Provider: OpenRouter (https://openrouter.ai)
- Model: `openai/gpt-4.1-nano` (configurable)
- Requires: API key from user (stored in UserDefaults)
- Images: Resized to max 2048px, JPEG 80% quality

### Parallel Image Processing
```swift
// Process all images concurrently
try await withThrowingTaskGroup(of: (Int, String).self) { group in
    for (index, image) in images.enumerated() {
        group.addTask {
            let result = try await ocrService.analyzeImage(image)
            return (index, result)
        }
    }
    // Sort by index to maintain order
    results.sort { $0.0 < $1.0 }
}
```

---

## Common Tasks & Where to Start

| Task | Entry Point | Notes |
|------|-------------|-------|
| Change AI model | `DeepSeekOCRService.swift` | Update `modelId` |
| Modify capture logic | `AutoCaptureService.swift` | `executeJob()` method |
| Add capture mode | `CaptureSettings.swift` | Add to `CaptureMode` enum |
| Change output format | `AutoCaptureService.swift` | `saveOutput()` method |
| Add UI setting | `ContentView.swift` | `SettingsSection` view |
| Handle permissions | `DuckDocsApp.swift` | Onboarding flow |

---

## Data Flow

```
User Configuration (CaptureJob)
    ↓
Start Capture → App hides (3s delay)
    ↓
Auto-Capture Loop:
    - Capture screenshot (ScreenCapture)
    - Perform next action (CGEvent.post)
    - Repeat n times
    ↓
App shows → Parallel AI Processing
    ↓
OpenRouter API (gpt-4.1-nano)
    ↓
Collect & sort results by index
    ↓
Save: output.md + /images folder
```

---

## Key Files

| File | Purpose |
|------|---------|
| `AutoCaptureService.swift` | Main capture workflow orchestrator |
| `DeepSeekOCRService.swift` | OpenRouter API client for image analysis |
| `ScreenCapture.swift` | ScreenCaptureKit wrapper |
| `CaptureJob.swift` | Job configuration (mode, action, count) |
| `CaptureSettings.swift` | CaptureMode enum |
| `ContentView.swift` | Main UI with settings |
| `RegionSelectorWindow.swift` | Drag-to-select region overlay |
| `WindowPickerView.swift` | Window selection sheet |

---

## Important Considerations

### Security & Privacy
- API key stored locally in UserDefaults
- Screenshots sent to external API (OpenRouter)
- Images saved locally in ~/Documents/DuckDocs/

### Performance
- Parallel image processing for faster AI analysis
- Images resized to max 2048px to reduce API payload
- JPEG compression (80%) for smaller file size

### Error Scenarios to Handle
- API key missing → Show error message
- API rate limit → Handle gracefully
- ScreenCapture permission denied → Prompt user
- Network error → Retry or show error
- Window not found → Fall back to full screen

---

## Testing Checklist

- [ ] Test full screen capture
- [ ] Test region selection
- [ ] Test window selection
- [ ] Test with different "next" actions (arrows, space, etc.)
- [ ] Test parallel processing with multiple images
- [ ] Test API error handling
- [ ] Test without API key

---

## Resources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [OpenRouter API](https://openrouter.ai/docs)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)

---

*This file is optimized for AI assistants.*
