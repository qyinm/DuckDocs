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
    @State private var recorder = ActionRecorder()
    @State private var player = ActionPlayer()
    @State private var ocrService = DeepSeekOCRService()

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(recorder: recorder)
        } detail: {
            if appState.selectedSequence != nil {
                DetailView(recorder: recorder, player: player, ocrService: ocrService)
            } else {
                ContentUnavailableView(
                    "No Sequence Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select a sequence from the sidebar or create a new recording.")
                )
            }
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
        .onAppear {
            if !appState.permissionManager.allPermissionsGranted {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Environment(AppState.self) var appState
    let recorder: ActionRecorder

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedSequence) {
            Section("Sequences") {
                ForEach(appState.sequences) { sequence in
                    NavigationLink(value: sequence) {
                        SequenceRow(sequence: sequence)
                    }
                }
                .onDelete(perform: deleteSequences)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .toolbar {
            ToolbarItem {
                Button(action: createNewSequence) {
                    Label("New Recording", systemImage: "plus")
                }
            }
        }
    }

    private func createNewSequence() {
        let sequence = ActionSequence(name: "New Recording \(appState.sequences.count + 1)")
        appState.addSequence(sequence)
        appState.selectedSequence = sequence
    }

    private func deleteSequences(at offsets: IndexSet) {
        for index in offsets {
            let sequence = appState.sequences[index]
            appState.deleteSequence(sequence)
        }
    }
}

// MARK: - Sequence Row

struct SequenceRow: View {
    let sequence: ActionSequence

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sequence.name)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(sequence.actionCount)", systemImage: "hand.tap")
                Label(formatDuration(sequence.totalDuration), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Detail View

struct DetailView: View {
    @Environment(AppState.self) var appState
    let recorder: ActionRecorder
    let player: ActionPlayer
    let ocrService: DeepSeekOCRService

    @State private var isExporting = false
    @State private var exportURL: URL?

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 20) {
            // Status indicator
            StatusBadge(mode: appState.mode)

            if let sequence = appState.selectedSequence {
                // Sequence info
                SequenceInfoView(sequence: sequence)

                Divider()

                // Control buttons
                ControlButtonsView(
                    sequence: sequence,
                    recorder: recorder,
                    player: player,
                    ocrService: ocrService,
                    isExporting: $isExporting,
                    exportURL: $exportURL
                )

                // Progress indicators
                ProgressSection(player: player, ocrService: ocrService, recorder: recorder)

                Spacer()

                // Action list
                if !sequence.actions.isEmpty {
                    ActionListView(actions: sequence.actions)
                }

                // Export result
                if let url = exportURL {
                    ExportResultView(url: url)
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Sequence Info View

struct SequenceInfoView: View {
    let sequence: ActionSequence

    var body: some View {
        VStack(spacing: 8) {
            Text(sequence.name)
                .font(.title)

            HStack(spacing: 20) {
                Label("\(sequence.actionCount) actions", systemImage: "hand.tap")
                Label(formatDuration(sequence.totalDuration), systemImage: "clock")
            }
            .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Control Buttons View

struct ControlButtonsView: View {
    @Environment(AppState.self) var appState
    let sequence: ActionSequence
    let recorder: ActionRecorder
    let player: ActionPlayer
    let ocrService: DeepSeekOCRService
    @Binding var isExporting: Bool
    @Binding var exportURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            // Record button
            if appState.mode == .idle {
                Button {
                    startRecording()
                } label: {
                    Label("Record", systemImage: "record.circle")
                }
            }

            // Stop recording button
            if appState.mode == .recording {
                Button {
                    stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .tint(.red)
            }

            // Play button
            if appState.mode == .idle && !sequence.actions.isEmpty {
                Button {
                    startPlayback()
                } label: {
                    Label("Play & Capture", systemImage: "play.circle")
                }
            }

            // Stop playback button
            if appState.mode == .playing {
                Button {
                    stopPlayback()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .tint(.red)
            }

            // Generate docs button
            if appState.mode == .idle && !player.captureResults.isEmpty {
                Button {
                    generateDocumentation()
                } label: {
                    Label("Generate Docs", systemImage: "doc.badge.gearshape")
                }
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private func startRecording() {
        appState.startRecording()
        recorder.startRecording(name: sequence.name)
    }

    private func stopRecording() {
        if let newSequence = recorder.stopRecording() {
            appState.updateSequence(newSequence)
            appState.selectedSequence = newSequence
        }
        appState.stopRecording()
    }

    private func startPlayback() {
        appState.startPlayback(sequence: sequence)
        player.play(sequence)

        player.onPlaybackComplete = { captures in
            Task { @MainActor in
                appState.stopPlayback()
                appState.currentSession?.captures = captures
            }
        }
    }

    private func stopPlayback() {
        player.stop()
        appState.stopPlayback()
    }

    private func generateDocumentation() {
        guard !player.captureResults.isEmpty else { return }

        isExporting = true
        appState.startProcessing()

        Task {
            do {
                print("[DuckDocs] Starting AI processing with \(player.captureResults.count) screenshots")

                // Analyze images with AI
                var analyses: [String] = []
                for (index, capture) in player.captureResults.enumerated() {
                    print("[DuckDocs] Processing screenshot \(index + 1)/\(player.captureResults.count)")
                    appState.processingProgress = Double(index) / Double(player.captureResults.count)
                    let analysis = try await ocrService.analyzeImage(capture.screenshot)
                    analyses.append(analysis)
                    print("[DuckDocs] Screenshot \(index + 1) analysis complete")
                }

                appState.processingProgress = 1.0
                print("[DuckDocs] All screenshots analyzed, generating markdown")

                // Generate markdown
                let generator = MarkdownGenerator()
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let outputDir = documentsDir.appendingPathComponent("DuckDocs/\(sequence.name)", isDirectory: true)

                let url = try generator.export(
                    title: sequence.name,
                    captures: player.captureResults,
                    aiAnalysis: analyses,
                    to: outputDir
                )

                print("[DuckDocs] Export complete: \(url.path)")
                exportURL = url
                appState.stopProcessing()
                isExporting = false
            } catch {
                print("[DuckDocs] Error: \(error)")
                appState.showError(message: error.localizedDescription)
                appState.stopProcessing()
                isExporting = false
            }
        }
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    @Environment(AppState.self) var appState
    let player: ActionPlayer
    let ocrService: DeepSeekOCRService
    let recorder: ActionRecorder

    var body: some View {
        VStack(spacing: 12) {
            if appState.mode == .playing {
                ProgressView(value: max(0, min(1, player.progress))) {
                    Text("Playing... (\(max(1, player.currentIndex + 1))/\(max(1, player.totalActions)))")
                }
            }

            if appState.mode == .processing {
                // Show model loading state
                switch ocrService.state {
                case .loading:
                    VStack(spacing: 8) {
                        ProgressView(value: max(0, min(1, ocrService.loadingProgress))) {
                            Text("Loading AI Model...")
                        }
                        Text("First time may take a while (~3GB download)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .processing:
                    ProgressView(value: max(0, min(1, appState.processingProgress))) {
                        Text("Analyzing screenshots...")
                    }
                case .error(let message):
                    VStack(spacing: 4) {
                        Label("Error", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .idle:
                    ProgressView(value: max(0, min(1, appState.processingProgress))) {
                        Text("Processing with AI...")
                    }
                }
            }

            if appState.mode == .recording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)

                    Text("Recording: \(recorder.actionCount) actions")
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

// MARK: - Export Result View

struct ExportResultView: View {
    let url: URL

    var body: some View {
        GroupBox("Export Complete") {
            VStack(alignment: .leading, spacing: 8) {
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Open in Finder") {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }

                    Button("Open File") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let mode: AppMode

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(mode.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch mode {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .playing:
            return .blue
        case .processing:
            return .orange
        }
    }
}

// MARK: - Action List View

struct ActionListView: View {
    let actions: [Action]

    var body: some View {
        GroupBox("Recorded Actions") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)

                            Text(action.description)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState.shared)
}
