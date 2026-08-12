//
//  RetroSeasonManagerApp.swift
//  Retro Season Manager
//
//  Created by John Derrick on 04/08/2026.
//

import SwiftUI

@main
struct RetroSeasonManagerApp: App {
    #if os(iOS)
    // Lock the game to landscape on iPhone and iPad.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
import UIKit

/// Restricts the app to landscape orientations.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }
}
#endif
