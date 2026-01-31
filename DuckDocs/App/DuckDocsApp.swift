//
//  DuckDocsApp.swift
//  DuckDocs
//
//  Created by hippoo on 1/30/26.
//

import SwiftUI

@main
struct DuckDocsApp: App {
    @State private var appState = AppState.shared
    @State private var captureService = AutoCaptureService()
    @State private var job = CaptureJob()

    init() {
        // API-based service, no preloading needed
    }

    var body: some Scene {
        WindowGroup {
            ContentView(captureService: $captureService, job: $job)
                .environment(appState)
                .onAppear {
                    setupKeyboardShortcuts()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Capture") {
                Button("Start Capture") {
                    startCapture()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!canStartCapture)

                Button("Stop Capture") {
                    stopCapture()
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(!canStopCapture)
            }
        }
    }

    private var canStartCapture: Bool {
        if case .idle = captureService.state { return true }
        if case .completed = captureService.state { return true }
        if case .error = captureService.state { return true }
        return false
    }

    private var canStopCapture: Bool {
        switch captureService.state {
        case .preparing, .capturing, .processing, .saving:
            return true
        default:
            return false
        }
    }

    private func setupKeyboardShortcuts() {
        let manager = KeyboardShortcutManager.shared
        manager.onStartCapture = { [self] in
            startCapture()
        }
        manager.onStopCapture = { [self] in
            stopCapture()
        }
        manager.start()
    }

    private func startCapture() {
        guard canStartCapture else { return }
        captureService.run(job: job, aiService: AIService.shared)
    }

    private func stopCapture() {
        guard canStopCapture else { return }
        captureService.cancel()
    }
}
