# DuckDocs - Context for AI Assistants

**Project:** DuckDocs  
**Type:** macOS Native App (Swift/SwiftUI)  
**Domain:** Automation + AI Document Generation  

---

## What This Project Does

DuckDocs automates the creation of documentation from user interactions:

1. **Record**: Captures mouse actions (clicks, drags, scrolls) via macOS Accessibility/CGEvent APIs
2. **Playback**: Replays actions automatically while taking screenshots at each step
3. **Generate**: Uses DeepSeek OCR 2 (MLX 4-bit) running locally on Apple Silicon to convert screenshots into structured markdown docs

**User Journey:** Record → Playback → AI Processing → Markdown Output

---

## When Working on This Project

### If Adding Recording Features
- Look at: `Sources/Recording/` 
- Key files: `ActionRecorder.swift`, `EventMonitor.swift`
- Must handle: Accessibility permission states, coordinate spaces (screen vs window)

### If Adding Playback Features
- Look at: `Sources/Playback/`
- Key files: `ActionPlayer.swift`, `ScreenCapture.swift`
- Must handle: Timing control, screenshot coordination, SCStream configuration

### If Adding AI Features
- Look at: `Sources/AI/`
- Key files: `VisionService.swift`, `MarkdownGenerator.swift`
- Must handle: Python environment, model loading, mlx-lm integration

### If Working on UI
- Look at: `Sources/Views/`
- Pattern: SwiftUI with MVVM, separate views for each mode

---

## Critical Technical Details

### CGEvent Monitoring
```swift
// Global event tap for mouse/keyboard
CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: callback,
    userInfo: userInfo
)
```
- Requires **Accessibility permission** (users must grant in System Settings)
- Event taps run on dedicated thread
- Must handle multiple displays (screen coordinates, not window)

### ScreenCaptureKit
```swift
// Modern screenshot API (macOS 12.3+)
let content = try await SCShareableContent.current
let filter = SCContentFilter(display: display, excludingWindows: [])
let stream = SCStream(filter: filter, configuration: config, delegate: self)
```
- Replaces deprecated CGDisplay APIs
- Supports window capture, display capture, or region capture
- Must handle stream lifecycle (start/stop properly)

### Vision Language Model Integration (mlx-swift-lm)
```swift
// Native Swift MLX inference
import MLXLMCommon
import MLXLLM

func analyzeImage(_ image: NSImage) async throws -> String {
    // 1. Load VLM model (auto-downloads on first use)
    let context = try await MLXLMCommon.loadModel(id: modelId)

    // 2. Create chat session with image processing
    let session = ChatSession(context, generateParameters: params, processing: processing)

    // 3. Save NSImage to temp file
    // 4. Analyze with VLM
    let result = try await session.respond(to: prompt, image: .url(tempURL))

    // 5. Cleanup temp file
}
```

**Model Details:**
- Model: `mlx-community/Qwen2.5-VL-3B-Instruct-4bit`
- Size: ~3GB (4-bit quantized)
- Requirements: Apple Silicon (M1/M2/M3/M4/M5), 8GB+ RAM
- First run: Auto-download on initial load
- Offline: 100% local, no internet required after download
- No Python required: Pure Swift implementation via mlx-swift-lm

---

## Common Tasks & Where to Start

| Task | Entry Point | Notes |
|------|-------------|-------|
| Add new action type | `ActionSequence.swift` (enum) → `EventMonitor.swift` → `ActionPlayer.swift` | Update all three |
| Change screenshot timing | `ScreenCapture.swift` | Modify capture trigger |
| Modify AI processing | `DeepSeekOCRService.swift` | mlx-swift-lm, VLM config |
| Modify output format | `MarkdownGenerator.swift` | Templates/prompts |
| Add UI screen | `Views/*.swift` | Follow SwiftUI MVVM |
| Handle permissions | `DuckDocsApp.swift` | Onboarding flow |

---

## Data Flow

```
User Actions
    ↓
CGEvent Monitor (CGEvent.tapCreate)
    ↓
ActionRecorder → [Action] array
    ↓
Save to JSON (Codable)
    ↓
Playback: ActionPlayer reads JSON
    ↓
For each action:
    - Replay action (CGEvent.post)
    - Capture screenshot (SCStream)
    ↓
DeepSeekOCRService (MLX local inference)
    ↓
MarkdownGenerator (structured output)
    ↓
output.md + /images folder
```

---

## Important Considerations

### Security & Privacy
- Never record keyboard input without explicit user consent
- Filter out password fields (check for secure input context)
- Store screenshots locally, not in cloud
- Clear sensitive data from logs

### Performance
- First model load: ~10-30s (~3GB download if not cached)
- Inference: ~1-3s per screenshot (Apple Silicon optimized via MLX)
- Subsequent loads: Faster (model cached in memory)
- Process screenshots in background queue
- Consider batching multiple images if possible
- M4/M5 chips benefit from Neural Accelerator optimizations

### Error Scenarios to Handle
- Accessibility permission denied → Show setup guide
- ScreenCapture permission denied → Prompt user
- Model download fails → Retry with progress indicator
- Insufficient memory → Warn user (8GB+ recommended)
- Multiple displays → Handle coordinate translation
- App not found during playback → Show error

---

## Testing Checklist

- [ ] Test with single display
- [ ] Test with multiple displays
- [ ] Test with Accessibility permission denied
- [ ] Test with ScreenCapture permission denied
- [ ] Test model loading on first run
- [ ] Test with insufficient RAM (4GB system)
- [ ] Test with large action sequences (100+ actions)
- [ ] Test playback speed variations
- [ ] Test memory usage with many screenshots

---

## Resources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
- [Accessibility Programming Guide](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [OpenAI Vision API](https://platform.openai.com/docs/guides/vision)
- [Claude Vision API](https://docs.anthropic.com/claude/docs/vision)

---

*This file is optimized for AI assistants. For general project knowledge, see AGENTS.md*
