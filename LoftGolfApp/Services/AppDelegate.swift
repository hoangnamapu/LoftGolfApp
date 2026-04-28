//
//  AppDelegate.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 4/12/26.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[PushDebug] APNs token: \(apnsToken)")

        Messaging.messaging().apnsToken = deviceToken

        Task {
            do {
                try await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "apnsToken": apnsToken,
                        "apnsUpdatedAt": FieldValue.serverTimestamp()
                    ], merge: true)

                print("[PushDebug] APNs token saved to Firestore")
            } catch {
                print("[PushDebug] Failed to save APNs token: \(error)")
            }
        }

        Messaging.messaging().token { token, error in
            if let error = error {
                print("[PushDebug] FCM token error after APNs token set: \(error)")
            } else {
                print("[PushDebug] FCM token after APNs token set: \(token ?? "nil")")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[PushDebug] APNs registration failed: \(error)")

        Task {
            do {
                try await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "apnsError": error.localizedDescription,
                        "apnsErrorUpdatedAt": FieldValue.serverTimestamp()
                    ], merge: true)

                print("[PushDebug] APNs error saved to Firestore")
            } catch {
                print("[PushDebug] Failed to save APNs error: \(error)")
            }
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("[PushDebug] FCM registration token is nil")
            return
        }

        print("[PushDebug] FCM registration token from delegate: \(token)")

        Task {
            await NotificationManager.shared.saveFCMToken(token)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[AppDelegate] Notification tapped: \(userInfo)")
        completionHandler()
    }
}
