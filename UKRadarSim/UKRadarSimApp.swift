//
//  UKRadarSimApp.swift
//  UKRadarSim
//
//  Created by Ian Dickson on 29/03/2026.
//

import SwiftUI

@main
struct UKRadarSimApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
