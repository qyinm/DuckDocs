# AI Module

**Purpose:** Convert screenshots to markdown via DeepSeek OCR 2 (local MLX inference)

## Files

| File | Role |
|------|------|
| `DeepSeekOCRService.swift` | DeepSeek OCR 2 (MLX 4-bit) integration via Python bridge |
| `MarkdownGenerator.swift` | Format AI responses into markdown |

## Key Concepts

### DeepSeek OCR 2 Integration
1. Save NSImage to temporary PNG file
2. Call Python mlx-lm via Process or PythonKit
3. Load model: `mlx-community/DeepSeek-OCR-2-4bit`
4. Generate structured markdown from screenshot
5. Cleanup temp file

### Model Details
- **Repository:** `mlx-community/DeepSeek-OCR-2-4bit`
- **Size:** ~4GB (4-bit quantized)
- **Requirements:** Apple Silicon (M1/M2/M3), 8GB+ RAM recommended
- **First run:** Auto-download on initial load (~10-30s)
- **Inference:** ~1-3s per screenshot
- **Offline:** 100% local, no API costs

## Where to Start

- **Modify model config:** `DeepSeekOCRService.swift` (temperature, max_tokens)
- **Change output format:** `MarkdownGenerator.swift` (templates)
- **Modify prompts:** `DeepSeekOCRService.swift` (system prompt)
- **Optimize performance:** Model caching, batch processing

## Dependencies

- Python 3.9+ with mlx-lm package
- PythonKit (for Swift-Python interop) OR Process (shell execution)
- No API keys needed

## Python Setup

```bash
pip install mlx-lm pillow
```

## Testing

- [ ] Test first model download (progress indicator)
- [ ] Test inference speed (1-3s per image)
- [ ] Test with 8GB RAM system
- [ ] Test error handling when Python not installed
- [ ] Test model cache persistence between sessions

## Implementation Notes

### Option A: Process (Shell Execution)
```swift
func analyzeImage(_ imagePath: String) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [
        "deepseek_ocr.py",
        "--image", imagePath,
        "--prompt", "Convert this UI screenshot to markdown documentation"
    ]
    // Execute and capture output
}
```

### Option B: PythonKit (Direct Integration)
```swift
import PythonKit

let mlx_lm = Python.import("mlx_lm")
let model = mlx_lm.load("mlx-community/DeepSeek-OCR-2-4bit")
// Direct Python object interaction
```

**Recommendation:** Start with Process approach for simplicity.
