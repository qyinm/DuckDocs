//
//  AutoCaptureService.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit
import CoreGraphics

/// Service for automatic capture workflow
@Observable
@MainActor
final class AutoCaptureService {
    enum State: Equatable {
        case idle
        case preparing
        case capturing(current: Int, total: Int)
        case processing(current: Int, total: Int)
        case saving
        case completed(URL)
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var capturedImages: [NSImage] = []

    private let screenCapture = ScreenCapture()
    private var captureTask: Task<Void, Never>?

    /// Start delay before capturing begins
    var startDelay: TimeInterval = 3.0

    init() {}

    /// Run the full auto-capture workflow
    func run(job: CaptureJob, ocrService: DeepSeekOCRService) {
        guard case .idle = state else { return }

        captureTask = Task {
            await executeJob(job, ocrService: ocrService)
        }
    }

    /// Cancel the current job
    func cancel() {
        captureTask?.cancel()
        captureTask = nil
        state = .idle
        capturedImages = []
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func executeJob(_ job: CaptureJob, ocrService: DeepSeekOCRService) async {
        capturedImages = []

        // Phase 1: Prepare - hide app and wait
        state = .preparing
        NSApp.hide(nil)

        try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))

        if Task.isCancelled { return }

        // Phase 2: Capture loop
        for i in 0..<job.captureCount {
            if Task.isCancelled { return }

            state = .capturing(current: i + 1, total: job.captureCount)

            // Take screenshot first (for the first one, capture current state)
            do {
                let image = try await capture(mode: job.captureMode)
                capturedImages.append(image)
            } catch {
                state = .error("Capture failed: \(error.localizedDescription)")
                showApp()
                return
            }

            // Perform next action (except after last capture)
            if i < job.captureCount - 1 {
                await performAction(job.nextAction)
                try? await Task.sleep(nanoseconds: UInt64(job.delayBetweenCaptures * 1_000_000_000))
            }
        }

        if Task.isCancelled { return }

        // Show app before processing
        showApp()

        // Phase 3: AI Processing (parallel)
        state = .processing(current: 0, total: capturedImages.count)

        let analyses: [String]
        do {
            analyses = try await processImagesInParallel(images: capturedImages, ocrService: ocrService)
        } catch {
            state = .error("AI processing failed: \(error.localizedDescription)")
            return
        }

        if Task.isCancelled { return }

        // Phase 4: Save
        state = .saving

        do {
            let url = try await saveOutput(job: job, analyses: analyses)
            state = .completed(url)
        } catch {
            state = .error("Save failed: \(error.localizedDescription)")
        }
    }

    private func capture(mode: CaptureMode) async throws -> NSImage {
        switch mode {
        case .fullScreen:
            return try await screenCapture.captureScreen()
        case .region(let rect):
            return try await screenCapture.captureRegion(rect)
        case .window(let windowID, _, _):
            return try await screenCapture.captureWindowByID(windowID)
        }
    }

    private func performAction(_ action: NextAction) async {
        switch action {
        case .keyPress(let keyCode, let modifiers):
            let cgFlags = modifiers.toCGEventFlags()

            if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) {
                keyDown.flags = cgFlags
                keyDown.post(tap: .cghidEventTap)
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false) {
                keyUp.flags = cgFlags
                keyUp.post(tap: .cghidEventTap)
            }

        case .click(let x, let y):
            let point = CGPoint(x: x, y: y)

            if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                       mouseCursorPosition: point, mouseButton: .left) {
                moveEvent.post(tap: .cghidEventTap)
            }

            try? await Task.sleep(nanoseconds: 50_000_000)

            if let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                       mouseCursorPosition: point, mouseButton: .left) {
                downEvent.post(tap: .cghidEventTap)
            }

            try? await Task.sleep(nanoseconds: 50_000_000)

            if let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                     mouseCursorPosition: point, mouseButton: .left) {
                upEvent.post(tap: .cghidEventTap)
            }

        case .none:
            break
        }
    }

    private func processImagesInParallel(images: [NSImage], ocrService: DeepSeekOCRService) async throws -> [String] {
        // Process all images concurrently and collect results with indices
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let result = try await ocrService.analyzeImage(image)
                    await MainActor.run {
                        // Update progress
                        self.state = .processing(current: index + 1, total: images.count)
                    }
                    return (index, result)
                }
            }

            // Collect results
            var results: [(Int, String)] = []
            for try await result in group {
                results.append(result)
            }

            // Sort by index to maintain original order
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }

    private func saveOutput(job: CaptureJob, analyses: [String]) async throws -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outputDir = documentsDir.appendingPathComponent("DuckDocs/\(job.outputName)_\(timestamp)", isDirectory: true)

        // Create directories
        let imagesDir = outputDir.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Save images
        var imageFilenames: [String] = []
        for (i, image) in capturedImages.enumerated() {
            let filename = "step_\(i + 1).png"
            let imageURL = imagesDir.appendingPathComponent(filename)

            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: imageURL)
                imageFilenames.append("images/\(filename)")
            }
        }

        // Generate markdown - only AI analysis content
        var markdown = ""

        for analysis in analyses {
            markdown += analysis + "\n\n"
        }

        // Save markdown
        let mdURL = outputDir.appendingPathComponent("\(job.outputName).md")
        try markdown.write(to: mdURL, atomically: true, encoding: .utf8)

        return mdURL
    }

    private func showApp() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
