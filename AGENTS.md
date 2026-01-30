# DuckDocs - Project Knowledge Base

**Generated:** 2026-01-30
**Project:** DuckDocs - Automated Screenshot to Documentation
**Stack:** Swift, SwiftUI, macOS

---

## OVERVIEW

DuckDocs is a macOS app that records user actions (clicks, drags, scrolls), plays them back with automatic screenshot capture, and uses DeepSeek OCR 2 (MLX 4-bit) running locally on Apple Silicon to generate structured markdown documentation.

**Core Value Proposition:** Click a few times, get complete documentation.

---

## PROJECT STRUCTURE

```
DuckDocs/
├── DuckDocs.xcodeproj
├── Sources/
│   ├── App/
│   │   └── DuckDocsApp.swift          # App entry point
│   ├── Recording/
│   │   ├── ActionRecorder.swift       # Main recording coordinator
│   │   ├── EventMonitor.swift         # CGEvent monitoring
│   │   └── ActionSequence.swift       # Data model for recorded actions
│   ├── Playback/
│   │   ├── ActionPlayer.swift         # Action replay engine
│   │   └── ScreenCapture.swift        # Screenshot capture (ScreenCaptureKit)
│   ├── AI/
│   │   ├── DeepSeekOCRService.swift   # DeepSeek OCR 2 (MLX 4-bit)
│   │   └── MarkdownGenerator.swift    # Markdown output generator
│   └── Views/
│       ├── RecordingView.swift        # Record UI
│       ├── PlaybackView.swift         # Playback UI
│       └── OutputView.swift           # Output preview UI
└── Resources/
```

---

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Start recording | `Recording/ActionRecorder.swift` | Main coordinator |
| Event capture | `Recording/EventMonitor.swift` | CGEvent taps |
| Data models | `Recording/ActionSequence.swift` | Action enum, structs |
| Replay actions | `Playback/ActionPlayer.swift` | Simulates user actions |
| Take screenshots | `Playback/ScreenCapture.swift` | ScreenCaptureKit |
| AI processing | `AI/VisionService.swift` | Vision API integration |
| Markdown gen | `AI/MarkdownGenerator.swift` | Output formatting |
| UI views | `Views/` | SwiftUI view components |

---

## DATA MODELS

```swift
// Core recording unit
struct ActionSequence: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let actions: [Action]
}

// Individual action types
enum Action: Codable {
    case click(x: CGFloat, y: CGFloat, type: ClickType)
    case drag(from: CGPoint, to: CGPoint)
    case scroll(direction: ScrollDirection, amount: CGFloat)
    case keypress(key: String, modifiers: [Modifier])
    case delay(seconds: Double)
}

// Screenshot capture result
struct CaptureResult {
    let action: Action
    let screenshot: NSImage
    let timestamp: Date
}
```

---

## CONVENTIONS

### Swift Style
- Use `Codable` for all data models (persistence)
- Prefer `struct` over `class` for value types
- Use `async/await` for async operations (Vision API calls)
- NSImage for screenshots (AppKit)

### macOS Permissions
- **Accessibility API** required for recording user actions
- **ScreenCaptureKit** required for screenshots
- Guide users through permission prompts on first launch

### Error Handling
- Use `Result<T, Error>` for operations that can fail
- Wrap CGEvent errors with descriptive messages
- Handle Vision API failures gracefully (timeout, rate limits)

---

## ANTI-PATTERNS (DO NOT)

- **DO NOT** use deprecated CGDisplay APIs for screenshots
- **DO NOT** store screenshots in memory long-term (write to disk)
- **DO NOT** capture passwords or sensitive data (respect privacy)
- **DO NOT** block main thread during Vision API calls
- **DO NOT** assume Accessibility permissions are granted

---

## UNIQUE REQUIREMENTS

### CGEvent Monitoring
- Use `CGEvent.tapCreate()` for global event monitoring
- Monitor: mouse clicks (left/right/double), drags, scrolls
- Store coordinates in screen space (handle multiple displays)

### ScreenCaptureKit (macOS 12.3+)
- Use `SCShareableContent` to get available displays/windows
- Use `SCStream` for continuous capture during playback
- Configure for high-resolution captures

### DeepSeek OCR 2 Integration (MLX-Community 4-bit)
- Model: `mlx-community/DeepSeek-OCR-2-4bit`
- Runs locally via Python mlx-lm library
- Apple Silicon optimized (M1/M2/M3)
- First run: ~4GB model download
- 100% offline, no API costs
- Handle model loading errors gracefully

---

## COMMANDS

```bash
# Build
xcodebuild -project DuckDocs.xcodeproj -scheme DuckDocs

# Run tests
xcodebuild test -project DuckDocs.xcodeproj -scheme DuckDocs

# Archive for distribution
xcodebuild -project DuckDocs.xcodeproj -scheme DuckDocs -configuration Release archive
```

---

## NOTES

### MVP Scope (v1.0)
- Click, drag, scroll recording only
- Full-screen capture during playback
- DeepSeek OCR 2 (MLX 4-bit) local AI processing
- Local JSON storage for action sequences

### Future (v1.1+)
- Keyboard input recording
- Browser-specific mode (URL tracking)
- Cloud sync
- Team sharing

### Key Dependencies
- ScreenCaptureKit (system)
- Accessibility API (system, requires permission)
- Python mlx-lm (DeepSeek OCR 2 model)
- PythonKit or Process (Swift-Python bridge)

### Testing Considerations
- Test on multiple display setups
- Test with different accessibility permission states
- Test Vision API rate limiting scenarios
