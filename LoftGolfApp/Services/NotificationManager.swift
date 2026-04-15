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
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[NotificationManager] Permission error: \(error)")
        }
    }

    // MARK: - Save FCM Token to Firestore

    func saveFCMToken(_ token: String) async {
        self.fcmToken = token
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(["fcmToken": token, "platform": "ios"], merge: true)
            print("[NotificationManager] FCM token saved for uid: \(uid)")
        } catch {
            print("[NotificationManager] Failed to save token: \(error)")
        }
    }

    // MARK: - Check Current Permission Status

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }
}
