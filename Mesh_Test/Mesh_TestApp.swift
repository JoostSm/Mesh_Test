//
//  Mesh_TestApp.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import SwiftUI

@main
struct Mesh_TestApp: App {
    
    init() {
        initializeBridgefy()  // Now it should be accessible here
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
