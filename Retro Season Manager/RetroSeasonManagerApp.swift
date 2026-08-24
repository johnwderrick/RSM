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
                .onAppear {
                    LandscapeLocker.forceLandscape()
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

/// Runtime belt-and-suspenders for the landscape lock. The app now declares
/// landscape-only orientations in Info.plist, so it cold-launches straight
/// into a landscape-shaped window. A scene can still start portrait in a few
/// situations (iPad multitasking, external displays, simulator quirks), so
/// this keeps asking until the window is genuinely landscape:
/// `requestGeometryUpdate` fails when the scene isn't active yet, so the
/// request is retried on scene activation and on failure instead of being
/// silently dropped.
enum LandscapeLocker {
    private static var retryCount = 0
    private static let maxRetries = 10
    private static var observer: NSObjectProtocol?

    /// Idempotent — safe to call from anywhere, any number of times.
    static func forceLandscape() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { _ in
                retryCount = 0
                forceLandscape()
            }
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .unattached }) else {
            scheduleRetry()
            return
        }
        apply(to: scene)
    }

    private static func apply(to scene: UIWindowScene) {
        guard !scene.interfaceOrientation.isLandscape else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { _ in
            scheduleRetry()
        }
    }

    private static func scheduleRetry() {
        guard retryCount < maxRetries else { return }
        retryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            forceLandscape()
        }
    }
}
#endif
