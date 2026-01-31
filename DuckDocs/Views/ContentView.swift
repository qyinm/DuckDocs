//
//  ContentView.swift
//  DuckDocs
//
//  Created by hippoo on 1/30/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var showOnboarding = false
    @Binding var captureService: AutoCaptureService
    @Binding var job: CaptureJob
    @State private var showWindowPicker = false
    private var aiService: AIService { AIService.shared }

    init(captureService: Binding<AutoCaptureService>, job: Binding<CaptureJob>) {
        self._captureService = captureService
        self._job = job
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("DuckDocs")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Auto-capture and generate documentation")
                    .foregroundStyle(.secondary)

                Divider()

                // Settings
                SettingsSection(job: $job, showWindowPicker: $showWindowPicker, aiService: aiService)

                Divider()

                // Status & Progress
                StatusSection(captureService: captureService)

                Spacer()
                    .frame(minHeight: 20)

                // Action Button
                ActionButton(
                    captureService: captureService,
                    job: job,
                    aiService: aiService
                )
            }
            .padding(32)
        }
        .frame(minWidth: 500, minHeight: 600)
        .task {
            // Wait for permission check to complete before deciding onboarding
            await appState.permissionManager.checkAllPermissions()
            if !appState.permissionManager.allPermissionsGranted {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showWindowPicker) {
            WindowPickerView { windowID, title, appName in
                job.captureMode = .window(windowID: windowID, title: title, appName: appName)
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection: View {
    @Binding var job: CaptureJob
    @Binding var showWindowPicker: Bool
    let aiService: AIService
    @State private var regionSelectorWindow: RegionSelectorWindow?
    @State private var selectedProvider: AIProviderType = AIService.shared.providerType
    @State private var selectedModelIndex: Int = 0
    @State private var customModel: String = ""
    @State private var apiKey: String = AIService.shared.apiKey
    @State private var useCustomModel: Bool = false
    @State private var baseURL: String = ""
    @State private var selectedTemplate: PromptTemplate = AIService.shared.selectedTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI Provider
            HStack {
                Text("AI Provider:")
                    .frame(width: 120, alignment: .trailing)

                Picker("", selection: $selectedProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .onChange(of: selectedProvider) { _, newValue in
                    aiService.switchProvider(newValue)
                    apiKey = aiService.apiKey
                    selectedModelIndex = 0
                    customModel = ""
                    useCustomModel = false
                    baseURL = aiService.config.baseURL ?? ""
                }
            }

            // Model Selection
            HStack {
                Text("Model:")
                    .frame(width: 120, alignment: .trailing)

                VStack(alignment: .leading, spacing: 8) {
                    if useCustomModel {
                        HStack {
                            TextField("model-name", text: $customModel)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customModel) { _, newValue in
                                    if !newValue.isEmpty {
                                        aiService.setModelId(newValue)
                                    }
                                }
                            Button("Presets") {
                                useCustomModel = false
                                if let first = selectedProvider.presetModels.first {
                                    aiService.setModelId(first)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        HStack {
                            Picker("", selection: $selectedModelIndex) {
                                ForEach(Array(selectedProvider.presetModels.enumerated()), id: \.offset) { index, model in
                                    Text(model).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .onChange(of: selectedModelIndex) { _, newValue in
                                let models = selectedProvider.presetModels
                                if newValue < models.count {
                                    aiService.setModelId(models[newValue])
                                }
                            }
                            Button("Custom") {
                                useCustomModel = true
                                customModel = aiService.modelId
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            // API Key
            if selectedProvider.requiresAPIKey || selectedProvider == .ollama {
                HStack {
                    Text("API Key:")
                        .frame(width: 120, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField(apiKeyPlaceholder, text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _, newValue in
                                aiService.apiKey = newValue
                            }
                        if selectedProvider == .ollama {
                            Text("Optional - for Ollama Cloud (ollama.com/settings/keys)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Base URL (for Ollama local or custom endpoints)
            if selectedProvider == .ollama {
                HStack {
                    Text("Server URL:")
                        .frame(width: 120, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("http://localhost:11434", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: baseURL) { _, newValue in
                                aiService.setBaseURL(newValue.isEmpty ? nil : newValue)
                            }
                        Text("Leave empty for local, or use https://ollama.com for cloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Output Name
            HStack {
                Text("Output Name:")
                    .frame(width: 120, alignment: .trailing)
                TextField("Documentation", text: $job.outputName)
                    .textFieldStyle(.roundedBorder)
            }

            // Capture Target
            HStack {
                Text("Capture Target:")
                    .frame(width: 120, alignment: .trailing)

                Menu {
                    Button("Full Screen") {
                        job.captureMode = .fullScreen
                    }
                    Button("Select Region...") {
                        showRegionSelector()
                    }
                    Button("Select Window...") {
                        showWindowPicker = true
                    }
                } label: {
                    HStack {
                        Image(systemName: job.captureMode.icon)
                        Text(job.captureMode.displayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: .infinity)
            }

            // Next Action
            HStack {
                Text("Next Action:")
                    .frame(width: 120, alignment: .trailing)

                Menu {
                    Button("→ Right Arrow") {
                        job.nextAction = .keyPress(keyCode: 124, modifiers: [])
                    }
                    Button("← Left Arrow") {
                        job.nextAction = .keyPress(keyCode: 123, modifiers: [])
                    }
                    Button("↓ Down Arrow") {
                        job.nextAction = .keyPress(keyCode: 125, modifiers: [])
                    }
                    Button("Space") {
                        job.nextAction = .keyPress(keyCode: 49, modifiers: [])
                    }
                    Button("Enter") {
                        job.nextAction = .keyPress(keyCode: 36, modifiers: [])
                    }
                    Button("None (Manual)") {
                        job.nextAction = .none
                    }
                } label: {
                    HStack {
                        Text(job.nextAction.displayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: .infinity)
            }

            // Capture Count
            HStack {
                Text("Capture Count:")
                    .frame(width: 120, alignment: .trailing)

                Stepper("\(job.captureCount) pages", value: $job.captureCount, in: 1...100)
            }

            // Delay
            HStack {
                Text("Delay:")
                    .frame(width: 120, alignment: .trailing)

                Slider(value: $job.delayBetweenCaptures, in: 0.2...3.0, step: 0.1)
                Text("\(job.delayBetweenCaptures, specifier: "%.1f")s")
                    .frame(width: 40)
            }

            // Prompt Template
            HStack {
                Text("Prompt Template:")
                    .frame(width: 120, alignment: .trailing)

                Picker("", selection: $selectedTemplate) {
                    ForEach(PromptTemplate.allCases) { template in
                        Label(template.rawValue, systemImage: template.icon).tag(template)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .onChange(of: selectedTemplate) { _, newValue in
                    aiService.setTemplate(newValue)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .onAppear {
            syncUIWithService()
        }
    }

    private var apiKeyPlaceholder: String {
        switch selectedProvider {
        case .openRouter: return "sk-or-..."
        case .openAI: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .ollama: return "ollama_... (optional for cloud)"
        }
    }

    private func syncUIWithService() {
        selectedProvider = aiService.providerType
        apiKey = aiService.apiKey
        baseURL = aiService.config.baseURL ?? ""
        selectedTemplate = aiService.selectedTemplate

        // Find current model in presets
        if let index = selectedProvider.presetModels.firstIndex(of: aiService.modelId) {
            selectedModelIndex = index
            useCustomModel = false
        } else {
            customModel = aiService.modelId
            useCustomModel = true
        }
    }

    private func showRegionSelector() {
        let window = RegionSelectorWindow()
        window.onRegionSelected = { rect in
            job.captureMode = .region(rect)
            regionSelectorWindow = nil
        }
        window.onCancelled = {
            regionSelectorWindow = nil
        }
        regionSelectorWindow = window
        window.show()
    }
}

// MARK: - Status Section

struct StatusSection: View {
    let captureService: AutoCaptureService

    var body: some View {
        VStack(spacing: 12) {
            switch captureService.state {
            case .idle:
                Label("Ready to capture", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)

            case .preparing:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Preparing... Switch to target app now!")
                        .foregroundStyle(.orange)
                }

            case .capturing(let current, let total):
                VStack(spacing: 8) {
                    ProgressView(value: Double(current), total: Double(total))
                    Text("Capturing: \(current) / \(total)")
                }

            case .processing(let current, let total):
                VStack(spacing: 8) {
                    ProgressView(value: Double(current), total: Double(total))
                    Text("AI Processing: \(current) / \(total)")
                }

            case .saving:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving...")
                }

            case .completed(let url):
                VStack(spacing: 12) {
                    Label("Completed!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)

                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Open Folder") {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                        Button("Open File") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

            case .error(let message):
                VStack(spacing: 8) {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Preview thumbnails
            if !captureService.capturedImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(captureService.capturedImages.enumerated()), id: \.offset) { index, image in
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 60)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 70)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let captureService: AutoCaptureService
    let job: CaptureJob
    let aiService: AIService

    var body: some View {
        switch captureService.state {
        case .idle, .completed, .error:
            Button {
                captureService.run(job: job, aiService: aiService)
            } label: {
                Label("Start Capture", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .preparing, .capturing, .processing, .saving:
            Button {
                captureService.cancel()
            } label: {
                Label("Cancel", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(captureService: .constant(AutoCaptureService()), job: .constant(CaptureJob()))
        .environment(AppState.shared)
}
