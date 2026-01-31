//
//  KeyboardShortcutManager.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-02-01.
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Manages global keyboard shortcuts
@MainActor
final class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    /// Callbacks
    var onStartCapture: (() -> Void)?
    var onStopCapture: (() -> Void)?

    private init() {}

    /// Start listening for keyboard shortcuts
    func start() {
        // Local monitor for when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume event
            }
            return event
        }

        // Global monitor for when app is inactive/hidden
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    /// Stop listening for keyboard shortcuts
    func stop() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Shift+S: Start Capture
        if flags == [.command, .shift] && event.keyCode == 1 { // 1 = 'S'
            onStartCapture?()
            return true
        }

        // Cmd+Shift+X: Stop/Cancel Capture
        if flags == [.command, .shift] && event.keyCode == 7 { // 7 = 'X'
            onStopCapture?()
            return true
        }

        return false
    }

    deinit {
        // Clean up will be called on MainActor
        Task { @MainActor in
            KeyboardShortcutManager.shared.stop()
        }
    }
}
