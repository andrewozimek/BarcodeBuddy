//
//  BarcodeApplicationScanner_AndrewOzimekApp.swift
//  BarcodeApplicationScanner_AndrewOzimek
//
//  Created by Ozimek, Andrew R. on 2/18/26.
//
//This launches the app and tells iOS to load ContentView as the first screen.

import SwiftUI

@main
struct BarcodeApplicationScanner_AndrewOzimekApp: App {
    
    init() {
        // Initialize database on app launch to avoid first-scan issues
        _ = DatabaseManager.shared
        print("🚀 App initialized - Database ready")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
