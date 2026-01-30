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
    @State private var captureService = AutoCaptureService()
    @State private var job = CaptureJob()
    @State private var showWindowPicker = false
    private var ocrService: DeepSeekOCRService { DeepSeekOCRService.shared }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("DuckDocs")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Auto-capture and generate documentation")
                .foregroundStyle(.secondary)

            Divider()

            // Settings
            SettingsSection(job: $job, showWindowPicker: $showWindowPicker)

            Divider()

            // Status & Progress
            StatusSection(captureService: captureService)

            Spacer()

            // Action Button
            ActionButton(
                captureService: captureService,
                job: job,
                ocrService: ocrService
            )
        }
        .padding(32)
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
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
    @State private var regionSelectorWindow: RegionSelectorWindow?
    @State private var apiKey: String = DeepSeekOCRService.shared.apiKey

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // API Key
            HStack {
                Text("API Key:")
                    .frame(width: 120, alignment: .trailing)
                SecureField("OpenRouter API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        DeepSeekOCRService.shared.apiKey = newValue
                        UserDefaults.standard.set(newValue, forKey: "openrouter_api_key")
                    }
            }

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
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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
    let ocrService: DeepSeekOCRService

    var body: some View {
        switch captureService.state {
        case .idle, .completed, .error:
            Button {
                captureService.run(job: job, ocrService: ocrService)
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
    ContentView()
        .environment(AppState.shared)
}
