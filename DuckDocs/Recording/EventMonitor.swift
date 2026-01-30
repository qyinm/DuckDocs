//
//  EventMonitor.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import CoreGraphics
import AppKit

/// Monitors global mouse events using CGEvent tap
@preconcurrency
final class EventMonitor: @unchecked Sendable {
    /// Callback when an action is captured
    var onActionCaptured: ((Action) -> Void)?

    /// Callback when monitoring fails
    var onError: ((Error) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    // For tracking drag operations
    private var dragStartPoint: CGPoint?
    private var lastEventTime: Date?

    // Click detection
    private var lastClickTime: Date?
    private var lastClickPoint: CGPoint?
    private let doubleClickInterval: TimeInterval = 0.3
    private let doubleClickRadius: CGFloat = 5.0

    init() {}

    deinit {
        stop()
    }

    /// Start monitoring mouse events
    func start() throws {
        guard !isRunning else { return }

        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw EventMonitorError.accessibilityNotGranted
        }

        // Define events to monitor
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        // Create event tap
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handleEvent(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        ) else {
            throw EventMonitorError.failedToCreateTap
        }

        eventTap = tap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else {
            throw EventMonitorError.failedToCreateRunLoopSource
        }

        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        lastEventTime = Date()
    }

    /// Stop monitoring mouse events
    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false
        dragStartPoint = nil
    }

    // MARK: - Event Handling

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let location = event.location

        // Calculate delay since last event
        let now = Date()
        if let lastTime = lastEventTime {
            let delay = now.timeIntervalSince(lastTime)
            if delay > 0.1 { // Only record significant delays
                onActionCaptured?(.delay(seconds: delay))
            }
        }
        lastEventTime = now

        switch type {
        case .leftMouseDown:
            dragStartPoint = location

        case .leftMouseUp:
            if let startPoint = dragStartPoint {
                let distance = hypot(location.x - startPoint.x, location.y - startPoint.y)

                if distance > 10 {
                    // This was a drag
                    onActionCaptured?(.drag(
                        fromX: startPoint.x,
                        fromY: startPoint.y,
                        toX: location.x,
                        toY: location.y
                    ))
                } else {
                    // This was a click - check for double click
                    let isDoubleClick = checkForDoubleClick(at: location)

                    if isDoubleClick {
                        onActionCaptured?(.doubleClick(x: location.x, y: location.y, button: .left))
                    } else {
                        onActionCaptured?(.click(x: location.x, y: location.y, button: .left))
                    }

                    lastClickTime = now
                    lastClickPoint = location
                }
            }
            dragStartPoint = nil

        case .rightMouseDown:
            // Right click - record immediately on mouse down
            break

        case .rightMouseUp:
            onActionCaptured?(.click(x: location.x, y: location.y, button: .right))

        case .scrollWheel:
            let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)

            if abs(deltaX) > 0.1 || abs(deltaY) > 0.1 {
                onActionCaptured?(.scroll(
                    x: location.x,
                    y: location.y,
                    deltaX: deltaX,
                    deltaY: deltaY
                ))
            }

        case .leftMouseDragged:
            // Dragging in progress - don't emit action yet
            break

        default:
            break
        }
    }

    private func checkForDoubleClick(at point: CGPoint) -> Bool {
        guard let lastTime = lastClickTime,
              let lastPoint = lastClickPoint else {
            return false
        }

        let timeDiff = Date().timeIntervalSince(lastTime)
        let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)

        return timeDiff < doubleClickInterval && distance < doubleClickRadius
    }
}

// MARK: - Errors

enum EventMonitorError: LocalizedError {
    case accessibilityNotGranted
    case failedToCreateTap
    case failedToCreateRunLoopSource

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required. Please enable it in System Settings > Privacy & Security > Accessibility."
        case .failedToCreateTap:
            return "Failed to create event tap. Make sure the app has Accessibility permission."
        case .failedToCreateRunLoopSource:
            return "Failed to create run loop source for event monitoring."
        }
    }
}
