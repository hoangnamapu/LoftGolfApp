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
        let center = UNUserNotificationCenter.current()

        do {
            let settingsBefore = await center.notificationSettings()
            print("[PushDebug] Permission status before request: \(settingsBefore.authorizationStatus.rawValue)")

            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted

            print("[PushDebug] Permission granted: \(granted)")

            let settingsAfter = await center.notificationSettings()
            print("[PushDebug] Permission status after request: \(settingsAfter.authorizationStatus.rawValue)")

            if granted {
                print("[PushDebug] Calling registerForRemoteNotifications")
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("[PushDebug] User denied notification permission")
            }
        } catch {
            print("[PushDebug] Permission error: \(error)")
        }
    }

    // MARK: - Save FCM Token to Firestore

    func saveFCMToken(_ token: String) async {
        self.fcmToken = token

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
