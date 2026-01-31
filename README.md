<p align="center">
  <img src="docs/site/favicon.svg" width="120" alt="DuckDocs">
</p>

<h1 align="center">DuckDocs</h1>

<p align="center">
  <strong>Auto-capture. AI-powered. Documentation done.</strong>
</p>

<p align="center">
  <a href="#coming-soon">Coming Soon</a> •
  <a href="#features">Features</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#supported-ai-providers">AI Providers</a> •
  <a href="#getting-started">Getting Started</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-coming%20soon-blue?style=flat-square" alt="Status">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/language-Swift-orange?style=flat-square" alt="Language">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

## Overview

DuckDocs automates the tedious process of creating documentation by capturing screenshots and converting them to structured markdown using AI. Perfect for documenting software workflows, user interfaces, processes, and tutorials.

Simply configure your capture settings, let DuckDocs automatically perform actions and capture screenshots, then watch as AI transforms those images into polished markdown documentation.

---

## Features

### Smart Screen Capture
- **Full Screen**: Capture the entire display
- **Region Selection**: Draw and capture a specific rectangular area
- **Window Selection**: Capture a specific application window
- **Auto-Action Loop**: Automatically perform actions (arrow keys, clicks, etc.) between captures

### AI-Powered Processing
- **Multi-Provider Support**: Choose from OpenRouter, OpenAI, Anthropic, or Ollama
- **Vision LLM Analysis**: Intelligent image-to-markdown conversion
- **Parallel Processing**: Process multiple images concurrently for speed
- **Custom Prompts**: Tailor AI analysis with custom prompts

### Markdown Export
- **Clean Output**: Well-structured markdown with embedded images
- **Organized Structure**: Screenshots saved in `images/` subdirectory
- **Timestamped**: Automatic timestamping for easy organization
- **Batched Documentation**: Multiple capture runs stored separately

---

## How It Works

DuckDocs operates in three simple phases:

### 1. Configure
Set up your capture job with these options:
- **Capture Mode**: Full screen, region, or specific window
- **Next Action**: What to do between captures (arrow key, space, click, etc.)
- **Capture Count**: How many screenshots to take
- **Output Name**: Name for your documentation

### 2. Auto-Capture
DuckDocs automatically:
- Hides the application (3-second delay)
- Captures your specified region/window/screen
- Performs the configured action (e.g., press right arrow)
- Repeats for the specified number of captures
- Shows the application when complete

### 3. AI Processing
Captured images are sent to your configured AI provider:
- Images processed in parallel (up to 5 concurrent)
- Vision LLM converts images to structured markdown
- Results compiled into a single markdown document
- Output saved to `~/Documents/DuckDocs/`

---

## Supported AI Providers

DuckDocs supports multiple AI providers, giving you flexibility in cost, latency, and model capabilities.

### OpenRouter
- **Best For**: Cost-effective with access to multiple models
- **Models**: GPT-4 Vision, Claude 3, Gemini Pro Vision, and more
- **Setup**: Get API key from [openrouter.ai](https://openrouter.ai)
- **Pricing**: Pay per use, competitive rates

### OpenAI
- **Best For**: State-of-the-art GPT-4 Vision capabilities
- **Model**: `gpt-4-vision-preview`
- **Setup**: Get API key from [platform.openai.com](https://platform.openai.com)
- **Requires**: OpenAI account with API access

### Anthropic
- **Best For**: Powerful Claude models with strong reasoning
- **Model**: Claude 3 Vision variants
- **Setup**: Get API key from [console.anthropic.com](https://console.anthropic.com)
- **Note**: Claude handles complex analysis exceptionally well

### Ollama (Local)
- **Best For**: Privacy-conscious users, offline operation
- **Models**: Llava, Bakllava, and other vision-capable models
- **Setup**: Install [Ollama](https://ollama.ai), run local server
- **Benefit**: No API costs, complete data privacy

---

## Requirements

### System Requirements
- **macOS 12.3+** (uses modern ScreenCaptureKit)
- **Apple Silicon (M1/M2/M3) or Intel Mac**
- **4GB RAM minimum** (8GB recommended for parallel processing)
- **Stable internet connection** (for cloud providers; not needed for Ollama)

### Permissions
DuckDocs requires macOS permissions for:
- **Screen Recording**: Needed for screenshot capture
- **Accessibility**: Needed for simulating keyboard/mouse actions
- **Keychain Access**: Optional (for secure API key storage)

---

## Installation

### Coming Soon

DuckDocs is currently in development and coming soon to the App Store.

In the meantime:
1. **Star this repository** to stay updated
2. **Watch releases** for the public beta announcement
3. **Check back regularly** for installation instructions

### For Early Access

If you're interested in early access, please:
- Open an [issue](https://github.com/qyinm/DuckDocs/issues) requesting beta access
- Star the repository to show your interest
- Share feature requests and feedback

---

## Quick Start Guide

Once installed, here's how to create your first documentation:

### Step 1: Configure AI Provider
1. Open DuckDocs
2. Go to Settings
3. Select your preferred AI provider (OpenRouter recommended for getting started)
4. Enter your API key
5. Test the connection

### Step 2: Set Up Capture
1. Choose your capture mode:
   - Full Screen for general UI documentation
   - Region for focused area documentation
   - Window for specific application documentation
2. Select the "next action" (e.g., Right Arrow to navigate slides)
3. Set capture count (how many screenshots to take)
4. Name your documentation

### Step 3: Start Capturing
1. Position your application as you want to start
2. Click "Start Capture"
3. DuckDocs hides and waits 3 seconds
4. Capture begins automatically
5. Return to normal when complete

### Step 4: Get Your Markdown
1. AI processing starts automatically
2. Progress indicator shows processing status
3. Once complete, open `~/Documents/DuckDocs/`
4. Your markdown file is ready to use

---

## Configuration

### AI Provider Setup

#### OpenRouter (Recommended)
```
1. Visit https://openrouter.ai/keys
2. Create an API key
3. Copy the key to DuckDocs Settings
4. Select desired model (gpt-4-vision recommended)
```

#### OpenAI
```
1. Visit https://platform.openai.com/api-keys
2. Create a new API key
3. Ensure GPT-4 Vision is available on your account
4. Copy the key to DuckDocs Settings
```

#### Anthropic
```
1. Visit https://console.anthropic.com/account/keys
2. Create an API key
3. Copy the key to DuckDocs Settings
4. Select Claude 3 model
```

#### Ollama (Local)
```
1. Install Ollama from https://ollama.ai
2. Pull a vision model: ollama pull llava
3. Start Ollama server (runs on http://localhost:11434)
4. In DuckDocs, select Ollama provider
5. Choose your model from the list
```

### Capture Settings

**Capture Mode**
- `Full Screen`: Entire display (default)
- `Region`: Custom rectangular area
- `Window`: Specific application window

**Next Action**
- Arrow keys (←, ↓, ↑, →)
- Space bar
- Return/Enter
- Tab
- Custom click positions
- None (static captures)

**Timing**
- `Capture Count`: 1-100 (default: 5)
- `Delay Between Captures`: 0.1-5.0 seconds (default: 0.5)
- `Start Delay`: 3 seconds before capture begins

---

## Tech Stack

### Core Technologies
- **Swift 5.9+**: Modern, type-safe implementation
- **SwiftUI**: Native macOS interface
- **ScreenCaptureKit**: Modern screenshot API (macOS 12.3+)
- **Async/Await**: Concurrent image processing

### AI Integration
- **OpenRouter API**: Multi-provider access
- **OpenAI Vision**: Direct GPT-4 Vision integration
- **Anthropic Claude**: Direct Claude API integration
- **Ollama**: Local vision model support

### Architecture
- **MVVM Pattern**: Clear separation of concerns
- **Observable Pattern**: Reactive UI updates
- **Concurrent Processing**: Task groups for parallel AI analysis
- **Keychain Integration**: Secure credential storage

---

## Output Format

DuckDocs generates well-organized documentation in the following structure:

```
~/Documents/DuckDocs/
└── YourDocName_2026-01-31T10-30-45/
    ├── YourDocName.md          (Main markdown file)
    └── images/
        ├── step_1.png
        ├── step_2.png
        ├── step_3.png
        └── ...
```

The markdown file contains:
- AI-generated descriptions of each screenshot
- Preserved structure and formatting
- Inline reference to images in the `images/` folder
- Ready for publishing to documentation sites

---

## Troubleshooting

### "Permission Denied" for Screen Recording
**Solution**: Go to System Preferences → Security & Privacy → Screen Recording, and enable DuckDocs.

### "Permission Denied" for Accessibility
**Solution**: Go to System Preferences → Security & Privacy → Accessibility, and enable DuckDocs.

### API Key Not Working
**Solution**:
1. Verify the API key is correct (no extra spaces)
2. Check that your API account has available credits
3. Ensure the provider is online at their status page
4. Test with a different AI provider

### Images Not Processing
**Solution**:
1. Check internet connection
2. Verify API key and credentials
3. Try a smaller number of images first
4. Check that your image resolution isn't too large

### Slow Processing
**Solution**:
- Use Ollama for faster local processing
- Reduce image resolution (DuckDocs auto-resizes to 2048px max)
- Decrease concurrent processing count in settings
- Use cheaper/faster models (GPT-4 Vision is slower than alternatives)

---

## Contributing

We welcome contributions! DuckDocs is open-source, and we'd love your help.

### Ways to Contribute
- **Report Bugs**: Open an [issue](https://github.com/qyinm/DuckDocs/issues)
- **Suggest Features**: Share your ideas in discussions
- **Submit Pull Requests**: Improvements are always welcome
- **Improve Documentation**: Help us document better
- **Share Feedback**: Let us know what works and what doesn't

### Development Setup
```bash
# Clone the repository
git clone https://github.com/qyinm/DuckDocs.git
cd DuckDocs

# Open in Xcode
open DuckDocs.xcodeproj

# Build and run
# Cmd+R in Xcode
```

### Code Guidelines
- Follow Swift API Design Guidelines
- Use descriptive variable names
- Add comments for complex logic
- Write concurrent-safe code
- Test on both Apple Silicon and Intel

---

## License

DuckDocs is released under the MIT License. See [LICENSE](LICENSE) file for details.

MIT License - feel free to use DuckDocs in commercial and personal projects.

---

## Acknowledgments

DuckDocs is built with modern Apple frameworks and community-driven AI providers:
- Apple ScreenCaptureKit team
- OpenRouter for aggregating AI models
- OpenAI, Anthropic, and Ollama communities
- macOS developer community

---

## Roadmap

### Current Status (Coming Soon)
- Core capture and AI processing
- Multi-provider support
- Basic markdown export

### Planned Features
- [ ] Templates for different documentation types
- [ ] Custom CSS styling for exports
- [ ] Batch processing multiple jobs
- [ ] Advanced image filtering and preprocessing
- [ ] Integration with GitHub/GitLab for direct commits
- [ ] Cloud sync for projects across devices
- [ ] Mobile companion app for configuration
- [ ] Video processing (convert to frame-by-frame documentation)

---

## Getting Help

### Documentation
- Check the [GitHub Wiki](https://github.com/qyinm/DuckDocs/wiki) (coming soon)
- Read through [open issues](https://github.com/qyinm/DuckDocs/issues) for solutions

### Support
- Open an [issue](https://github.com/qyinm/DuckDocs/issues) for bugs
- Start a [discussion](https://github.com/qyinm/DuckDocs/discussions) for questions
- Email: [feedback@duckdocs.dev](mailto:feedback@duckdocs.dev) (coming soon)

### Community
- Follow [@DuckDocsApp](https://twitter.com/DuckDocsApp) on Twitter (coming soon)
- Join our Discord server (coming soon)

---

## Star History

If you find DuckDocs useful, please star the repository to show your support!

[![Star History](https://api.star-history.com/svg?repos=qyinm/DuckDocs&type=Date)](https://star-history.com/#qyinm/DuckDocs&Date)

---

<p align="center">
  Made with care by the DuckDocs team
  <br/>
  <a href="https://github.com/qyinm/DuckDocs">GitHub</a> •
  <a href="https://github.com/qyinm/DuckDocs/issues">Issues</a> •
  <a href="https://github.com/qyinm/DuckDocs/discussions">Discussions</a>
</p>
