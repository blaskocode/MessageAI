//
//  NotificationService.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

/// Handles push notification setup and management
class NotificationService: NSObject, ObservableObject {
    
    static let shared = NotificationService()
    
    @Published var fcmToken: String?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    func saveFCMToken(for userId: String) async {
        guard let token = fcmToken else { return }
        
        do {
            try await FirebaseService.shared.updateUserProfile(userId: userId, updates: ["fcmToken": token])
            print("✅ FCM token saved for user: \(userId)")
        } catch {
            print("❌ Error saving FCM token: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract conversation ID from notification
        if let conversationId = userInfo["conversationId"] as? String {
            print("📱 Opening conversation: \(conversationId)")
            // TODO: Navigate to conversation
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        print("✅ FCM Token received: \(fcmToken ?? "none")")
    }
}

