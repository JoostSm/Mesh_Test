//
//  Mesh_TestApp.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import SwiftUI

@main
struct Mesh_TestApp: App {
    @StateObject private var logManager = LogManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(logManager)
        }
    }
}
