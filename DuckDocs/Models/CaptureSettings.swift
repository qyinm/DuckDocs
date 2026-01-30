//
//  CaptureSettings.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import CoreGraphics

/// Capture mode for screenshots during playback
enum CaptureMode: Equatable {
    case fullScreen
    case region(CGRect)
    case window(windowID: CGWindowID, title: String, appName: String)

    var displayName: String {
        switch self {
        case .fullScreen:
            return "Full Screen"
        case .region(let rect):
            return "Region (\(Int(rect.width))x\(Int(rect.height)))"
        case .window(_, let title, let appName):
            if title.isEmpty {
                return appName
            }
            return "\(appName) - \(title)"
        }
    }

    var icon: String {
        switch self {
        case .fullScreen:
            return "rectangle.dashed"
        case .region:
            return "rectangle.dashed.badge.record"
        case .window:
            return "macwindow"
        }
    }
}

/// Settings for screen capture during playback
struct CaptureSettings {
    var mode: CaptureMode = .fullScreen
}
