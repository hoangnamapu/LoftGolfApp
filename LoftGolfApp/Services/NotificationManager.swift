//
//  NotificationManager.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 4/12/26.
//

import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    @Published var permissionGranted: Bool = false
    @Published var fcmToken: String? = nil

    private override init() { super.init() }

    // MARK: - Request Permission

    func requestPermission() async {
        try? await Firestore.firestore()
            .collection("debug_fcm_tokens")
            .document("latest_ios_token")
            .setData(["permissionFuncCalled": true, "permissionFuncCalledAt": FieldValue.serverTimestamp()], merge: true)

        let center = UNUserNotificationCenter.current()

        do {
            let settingsBefore = await center.notificationSettings()
            print("[PushDebug] Permission status before request: \(settingsBefore.authorizationStatus.rawValue)")

            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted

            let settingsAfter = await center.notificationSettings()
            print("[PushDebug] Permission granted: \(granted)")
            print("[PushDebug] Permission status after request: \(settingsAfter.authorizationStatus.rawValue)")

            let canRegister =
                settingsAfter.authorizationStatus == .authorized ||
                settingsAfter.authorizationStatus == .provisional ||
                settingsAfter.authorizationStatus == .ephemeral

            if canRegister {
                print("[PushDebug] Registering for APNs remote notifications")

                UIApplication.shared.registerForRemoteNotifications()

                try await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "registerForRemoteNotificationsCalled": true,
                        "registerCalledAt": FieldValue.serverTimestamp(),
                        "authorizationStatus": settingsAfter.authorizationStatus.rawValue
                    ], merge: true)
            } else {
                print("[PushDebug] Notification permission not authorized")

                try await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "registerForRemoteNotificationsCalled": false,
                        "authorizationStatus": settingsAfter.authorizationStatus.rawValue,
                        "registerSkippedAt": FieldValue.serverTimestamp()
                    ], merge: true)
            }
        } catch {
            print("[PushDebug] Permission error: \(error)")

            do {
                try await Firestore.firestore()
                    .collection("debug_fcm_tokens")
                    .document("latest_ios_token")
                    .setData([
                        "permissionError": error.localizedDescription,
                        "permissionErrorAt": FieldValue.serverTimestamp()
                    ], merge: true)
            } catch {
                print("[PushDebug] Failed to save permission error: \(error)")
            }
        }
    }

    // MARK: - Save FCM Token to Firestore

    func saveFCMToken(_ token: String) async {
        self.fcmToken = token

        do {
            try await Messaging.messaging().subscribe(toTopic: "all_users")

            try await Firestore.firestore()
                .collection("debug_fcm_tokens")
                .document("latest_ios_token")
                .setData([
                    "topicSubscribed": true,
                    "topicName": "all_users",
                    "topicSubscribedAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("[PushDebug] Successfully subscribed to topic: all_users")
        } catch {
            try? await Firestore.firestore()
                .collection("debug_fcm_tokens")
                .document("latest_ios_token")
                .setData([
                    "topicSubscribed": false,
                    "topicName": "all_users",
                    "topicSubscribeError": error.localizedDescription,
                    "topicSubscribeErrorAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("[PushDebug] Failed to subscribe to topic all_users: \(error)")
        }

        print("[PushDebug] saveFCMToken called")
        print("[PushDebug] FCM token value: \(token)")

        do {
            try await Firestore.firestore()
                .collection("debug_fcm_tokens")
                .document("latest_ios_token")
                .setData([
                    "fcmToken": token,
                    "platform": "ios",
                    "deviceName": UIDevice.current.name,
                    "systemName": UIDevice.current.systemName,
                    "systemVersion": UIDevice.current.systemVersion,
                    "model": UIDevice.current.model,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("[PushDebug] FCM token saved to Firestore: debug_fcm_tokens/latest_ios_token")
        } catch {
            print("[PushDebug] Failed to save FCM token to Firestore: \(error)")
        }
    }

    // MARK: - Check Current Permission Status

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized

        print("[NotificationManager] Permission status: \(settings.authorizationStatus.rawValue)")
        // 0 = notDetermined, 1 = denied, 2 = authorized
    }
}
