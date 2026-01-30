//
//  AppState.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import SwiftUI

/// Application state enumeration
enum AppMode: String, CaseIterable {
    case idle = "Ready"
    case recording = "Recording"
    case playing = "Playing"
    case processing = "Processing"
}

/// Global application state manager
@Observable
@MainActor
final class AppState {
    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Properties

    /// Current application mode
    var mode: AppMode = .idle

    /// Permission manager
    var permissionManager = PermissionManager()

    /// All saved action sequences
    var sequences: [ActionSequence] = []

    /// Currently selected sequence
    var selectedSequence: ActionSequence?

    /// Current playback session (when playing)
    var currentSession: PlaybackSession?

    /// Recording progress
    var recordingActionCount: Int = 0

    /// Playback progress (0.0 to 1.0)
    var playbackProgress: Double = 0.0

    /// AI processing progress (0.0 to 1.0)
    var processingProgress: Double = 0.0

    /// Current error message
    var errorMessage: String?

    /// Show error alert
    var showError: Bool = false

    // MARK: - Initialization

    private init() {
        loadSequences()
    }

    // MARK: - Sequence Management

    /// Load all sequences from disk
    func loadSequences() {
        sequences = ActionSequence.loadAll()
    }

    /// Add a new sequence
    func addSequence(_ sequence: ActionSequence) {
        do {
            try sequence.save()
            sequences.insert(sequence, at: 0)
        } catch {
            showError(message: "Failed to save sequence: \(error.localizedDescription)")
        }
    }

    /// Delete a sequence
    func deleteSequence(_ sequence: ActionSequence) {
        do {
            try sequence.delete()
            sequences.removeAll { $0.id == sequence.id }
            if selectedSequence?.id == sequence.id {
                selectedSequence = nil
            }
        } catch {
            showError(message: "Failed to delete sequence: \(error.localizedDescription)")
        }
    }

    /// Update a sequence
    func updateSequence(_ sequence: ActionSequence) {
        do {
            try sequence.save()
            if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
                sequences[index] = sequence
            }
            if selectedSequence?.id == sequence.id {
                selectedSequence = sequence
            }
        } catch {
            showError(message: "Failed to update sequence: \(error.localizedDescription)")
        }
    }

    // MARK: - Mode Transitions

    /// Start recording
    func startRecording() {
        guard mode == .idle else { return }
        guard permissionManager.accessibilityGranted else {
            showError(message: "Accessibility permission required for recording")
            return
        }

        mode = .recording
        recordingActionCount = 0
    }

    /// Stop recording
    func stopRecording() {
        guard mode == .recording else { return }
        mode = .idle
    }

    /// Start playback
    func startPlayback(sequence: ActionSequence) {
        guard mode == .idle else { return }
        guard permissionManager.allPermissionsGranted else {
            showError(message: "All permissions required for playback")
            return
        }

        mode = .playing
        playbackProgress = 0.0
        currentSession = PlaybackSession(
            sequenceId: sequence.id,
            sequenceName: sequence.name
        )
    }

    /// Stop playback
    func stopPlayback() {
        guard mode == .playing else { return }
        mode = .idle
        playbackProgress = 0.0
    }

    /// Start AI processing
    func startProcessing() {
        guard mode == .idle else { return }
        guard currentSession != nil else { return }

        mode = .processing
        processingProgress = 0.0
    }

    /// Stop AI processing
    func stopProcessing() {
        guard mode == .processing else { return }
        mode = .idle
        processingProgress = 0.0
    }

    /// Reset to idle state
    func reset() {
        mode = .idle
        playbackProgress = 0.0
        processingProgress = 0.0
        recordingActionCount = 0
    }

    // MARK: - Error Handling

    func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
