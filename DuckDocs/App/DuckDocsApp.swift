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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
