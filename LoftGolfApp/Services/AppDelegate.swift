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

        requestNotificationPermission(application: application)

        return true
    }

    private func requestNotificationPermission(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in

            Task {
                try? await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "appDelegateRequestPermissionCalled": true,
                        "appDelegatePermissionGranted": granted,
                        "appDelegatePermissionError": error?.localizedDescription ?? "",
                        "appDelegatePermissionCheckedAt": FieldValue.serverTimestamp()
                    ], merge: true)
            }

            guard granted else {
                print("[PushDebug] Notification permission denied")
                return
            }

            DispatchQueue.main.async {
                print("[PushDebug] AppDelegate registering for APNs")
                application.registerForRemoteNotifications()

                Task {
                    try? await Firestore.firestore()
                        .collection("debug_fcm_tokens")
                        .document("latest_ios_token")
                        .setData([
                            "appDelegateRegisterCalled": true,
                            "appDelegateRegisterCalledAt": FieldValue.serverTimestamp()
                        ], merge: true)
                }
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[PushDebug] APNs token: \(apnsToken)")

        Messaging.messaging().apnsToken = deviceToken

        Task {
            try? await Firestore.firestore()
                .collection("debug_fcm_tokens")
                .document("latest_ios_token")
                .setData([
                    "apnsToken": apnsToken,
                    "apnsUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        }

        Messaging.messaging().token { token, error in
            Task {
                try? await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "fcmTokenAfterApns": token ?? "",
                        "fcmTokenAfterApnsError": error?.localizedDescription ?? "",
                        "fcmTokenAfterApnsAt": FieldValue.serverTimestamp()
                    ], merge: true)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[PushDebug] APNs registration failed: \(error)")

        Task {
            try? await Firestore.firestore()
                .collection("debug_fcm_tokens")
                .document("latest_ios_token")
                .setData([
                    "apnsError": error.localizedDescription,
                    "apnsErrorUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task {
            await NotificationManager.shared.saveFCMToken(token)
        }
    }
}

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
        print("[PushDebug] Notification tapped: \(response.notification.request.content.userInfo)")
        completionHandler()
    }
}
