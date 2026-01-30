//
//  ContentView.swift
//  DuckDocs
//
//  Created by hippoo on 1/30/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Sidebar: Sequence List
            List(selection: $appState.selectedSequence) {
                Section("Sequences") {
                    ForEach(appState.sequences) { sequence in
                        NavigationLink(value: sequence) {
                            VStack(alignment: .leading) {
                                Text(sequence.name)
                                    .font(.headline)
                                Text("\(sequence.actionCount) actions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
        } detail: {
            // Main content area
            if appState.selectedSequence != nil {
                DetailView()
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
    }

    private func createNewSequence() {
        let sequence = ActionSequence(name: "New Recording")
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

// MARK: - Detail View

struct DetailView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 20) {
            // Status indicator
            StatusBadge(mode: appState.mode)

            if let sequence = appState.selectedSequence {
                // Sequence info
                VStack(spacing: 8) {
                    Text(sequence.name)
                        .font(.title)

                    HStack(spacing: 20) {
                        Label("\(sequence.actionCount) actions", systemImage: "hand.tap")
                        Label(formatDuration(sequence.totalDuration), systemImage: "clock")
                    }
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        appState.startRecording()
                    } label: {
                        Label("Record", systemImage: "record.circle")
                    }
                    .disabled(appState.mode != .idle)

                    Button {
                        appState.startPlayback(sequence: sequence)
                    } label: {
                        Label("Play", systemImage: "play.circle")
                    }
                    .disabled(appState.mode != .idle || sequence.actions.isEmpty)

                    if appState.mode == .recording {
                        Button {
                            appState.stopRecording()
                        } label: {
                            Label("Stop", systemImage: "stop.circle")
                        }
                        .tint(.red)
                    }

                    if appState.mode == .playing {
                        Button {
                            appState.stopPlayback()
                        } label: {
                            Label("Stop", systemImage: "stop.circle")
                        }
                        .tint(.red)
                    }
                }
                .buttonStyle(.borderedProminent)

                // Progress indicators
                if appState.mode == .playing {
                    ProgressView(value: appState.playbackProgress) {
                        Text("Playing...")
                    }
                    .padding()
                }

                if appState.mode == .processing {
                    ProgressView(value: appState.processingProgress) {
                        Text("Processing with AI...")
                    }
                    .padding()
                }

                Spacer()

                // Action list preview
                if !sequence.actions.isEmpty {
                    ActionListView(actions: sequence.actions)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
