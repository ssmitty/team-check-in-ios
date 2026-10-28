// NotificationAppDelegate.swift
// Purpose: Bridge notification taps into the account-scoped SwiftUI route inbox.
import UIKit
import UserNotifications

/// Installs the delegate at launch so cold-start taps can wait for account restoration.
@MainActor
final class NotificationAppDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    let routes = NotificationRouteInbox()
    let registration = NotificationRegistrationInbox()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        registration.token = deviceToken
        registration.failureID = nil
    }
    func application(
        _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        registration.failureID = UUID()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let gameID = response.notification.request.content.userInfo["game_id"] as? String
        await receive(gameID)
    }

    private func receive(_ gameID: String?) {
        routes.receive(gameID: gameID)
    }
}
