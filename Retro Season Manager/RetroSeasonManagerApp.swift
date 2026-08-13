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
                #if os(iOS)
                // Belt-and-suspenders alongside `AppDelegate`'s orientation
                // mask: on some cold launches UIKit doesn't consult that
                // delegate method early enough to rotate out of portrait
                // before the first frame draws, leaving a landscape-only
                // app stuck rendering sideways in a portrait-shaped window
                // until something else triggers a relayout. Requesting the
                // geometry update directly as soon as a window scene exists
                // closes that gap.
                .onAppear {
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                }
                #endif
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
