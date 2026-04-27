//
//  NotificationManager.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 4/12/26.
//

import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
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

                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
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

        guard let uid = Auth.auth().currentUser?.uid else {
            print("[PushDebug] No FirebaseAuth currentUser, token not saved to Firestore")
            return
        }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData([
                    "fcmToken": token,
                    "platform": "ios",
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("[PushDebug] FCM token saved for FirebaseAuth uid: \(uid)")
        } catch {
            print("[PushDebug] Failed to save token: \(error)")
        }
    }

    // MARK: - Check Current Permission Status

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
        print("[NotificationManager] Permission status: \(settings.authorizationStatus.rawValue)")
        // 0=notDetermined, 1=denied, 2=authorized
    }
}
