//
//  DownloadNotificationManager.swift
//  KinoPubKit
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation
import OSLog
import KinoPubLogging

#if os(iOS)
import UserNotifications
import UIKit

// MARK: - Constants (Outside Generic Class)
private enum NotificationCategories {
  static let downloadComplete = "DOWNLOAD_COMPLETE"
  static let downloadFailed = "DOWNLOAD_FAILED"
  static let downloadProgress = "DOWNLOAD_PROGRESS"
}

private enum ActionIdentifiers {
  static let openFile = "OPEN_FILE"
  static let dismiss = "DISMISS"
  static let retryDownload = "RETRY_DOWNLOAD"
}

// MARK: - Download Notification Manager
public class DownloadNotificationManager: NSObject, ObservableObject {
  
  // MARK: - Properties
  @Published public private(set) var notificationPermissionGranted: Bool = false
  @Published public private(set) var notificationSettings: UNNotificationSettings?
  
  private let notificationCenter = UNUserNotificationCenter.current()
  
  // MARK: - Initialization
  override public init() {
    super.init()
    notificationCenter.delegate = self
    setupNotificationCategories()
    checkNotificationPermission()
  }
  
  // MARK: - Public Methods
  public func requestNotificationPermission() async -> Bool {
    do {
      let granted = try await notificationCenter.requestAuthorization(
        options: [.alert, .sound, .badge, .provisional]
      )
      
      await MainActor.run {
        self.notificationPermissionGranted = granted
      }
      
      if granted {
        Logger.kit.info("[NOTIFICATIONS] Permission granted for download notifications")
      } else {
        Logger.kit.warning("[NOTIFICATIONS] Permission denied for download notifications")
      }
      
      return granted
    } catch {
      Logger.kit.error("[NOTIFICATIONS] Failed to request permission: \(error)")
      return false
    }
  }
  
  public func scheduleDownloadCompleteNotification<Meta: Codable & Equatable>(
    for fileInfo: DownloadedFileInfo<Meta>,
    localURL: URL
  ) {
    guard notificationPermissionGranted else { return }
    
    let content = UNMutableNotificationContent()
    content.title = "Download Complete"
    content.body = "'\(fileInfo.localFilename)' has finished downloading"
    content.sound = .default
    content.categoryIdentifier = NotificationCategories.downloadComplete
    
    // Add custom data for handling tap
    content.userInfo = [
      "fileURL": localURL.path,
      "fileName": fileInfo.localFilename,
      "downloadDate": ISO8601DateFormatter().string(from: fileInfo.downloadDate)
    ]
    
    // Badge increment  
    content.badge = NSNumber(value: 1)
    
    // Immediate delivery
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let identifier = "download_complete_\(fileInfo.originalURL.absoluteString.hash)"
    
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
    
    notificationCenter.add(request) { error in
      if let error = error {
        Logger.kit.error("[NOTIFICATIONS] Failed to schedule download complete notification: \(error)")
      } else {
        Logger.kit.info("[NOTIFICATIONS] Scheduled download complete notification for: \(fileInfo.localFilename)")
      }
    }
  }
  
  public func scheduleDownloadFailedNotification(
    for url: URL,
    fileName: String,
    error: Error
  ) {
    guard notificationPermissionGranted else { return }
    
    let content = UNMutableNotificationContent()
    content.title = "Download Failed"
    content.body = "'\(fileName)' failed to download"
    content.sound = .default
    content.categoryIdentifier = NotificationCategories.downloadFailed
    
    content.userInfo = [
      "fileURL": url.absoluteString,
      "fileName": fileName,
      "error": error.localizedDescription
    ]
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let identifier = "download_failed_\(url.absoluteString.hash)"
    
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
    
    notificationCenter.add(request) { error in
      if let error = error {
        Logger.kit.error("[NOTIFICATIONS] Failed to schedule download failed notification: \(error)")
      } else {
        Logger.kit.info("[NOTIFICATIONS] Scheduled download failed notification for: \(fileName)")
      }
    }
  }
  
  public func scheduleProgressNotification(
    for fileName: String,
    progress: Float,
    url: URL
  ) {
    guard notificationPermissionGranted,
          progress > 0.5, // Only show for significant progress
          Int(progress * 100) % 25 == 0 else { return } // Every 25% increment
    
    let content = UNMutableNotificationContent()
    content.title = "Download Progress"
    content.body = "'\(fileName)' is \(Int(progress * 100))% complete"
    content.sound = nil // Silent for progress updates
    content.categoryIdentifier = NotificationCategories.downloadProgress
    
    content.userInfo = [
      "fileURL": url.absoluteString,
      "fileName": fileName,
      "progress": progress
    ]
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let identifier = "download_progress_\(url.absoluteString.hash)"
    
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
    
    // Remove previous progress notification for same file
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    
    notificationCenter.add(request) { error in
      if let error = error {
        Logger.kit.debug("[NOTIFICATIONS] Failed to schedule progress notification: \(error)")
      }
    }
  }
  
  public func clearAllDownloadNotifications() {
    notificationCenter.removeAllPendingNotificationRequests()
    notificationCenter.removeAllDeliveredNotifications()
    
    // Reset badge
    UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    
    Logger.kit.info("[NOTIFICATIONS] Cleared all download notifications")
  }
  
  public func clearNotifications(for url: URL) {
    let identifiers = [
      "download_complete_\(url.absoluteString.hash)",
      "download_failed_\(url.absoluteString.hash)",
      "download_progress_\(url.absoluteString.hash)"
    ]
    
    notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
  }
  
  // MARK: - Private Methods
  private func setupNotificationCategories() {
    // Download Complete actions
    let openAction = UNNotificationAction(
      identifier: ActionIdentifiers.openFile,
      title: "Open",
      options: [.foreground]
    )
    
    let dismissAction = UNNotificationAction(
      identifier: ActionIdentifiers.dismiss,
      title: "Dismiss",
      options: []
    )
    
    let completeCategory = UNNotificationCategory(
      identifier: NotificationCategories.downloadComplete,
      actions: [openAction, dismissAction],
      intentIdentifiers: [],
      options: []
    )
    
    // Download Failed actions
    let retryAction = UNNotificationAction(
      identifier: ActionIdentifiers.retryDownload,
      title: "Retry",
      options: [.foreground]
    )
    
    let failedCategory = UNNotificationCategory(
      identifier: NotificationCategories.downloadFailed,
      actions: [retryAction, dismissAction],
      intentIdentifiers: [],
      options: []
    )
    
    // Progress category (no actions)
    let progressCategory = UNNotificationCategory(
      identifier: NotificationCategories.downloadProgress,
      actions: [],
      intentIdentifiers: [],
      options: []
    )
    
    notificationCenter.setNotificationCategories([
      completeCategory,
      failedCategory,
      progressCategory
    ])
  }
  
  private func checkNotificationPermission() {
    notificationCenter.getNotificationSettings { [weak self] settings in
      DispatchQueue.main.async {
        self?.notificationSettings = settings
        self?.notificationPermissionGranted = settings.authorizationStatus == .authorized ||
                                              settings.authorizationStatus == .provisional
      }
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension DownloadNotificationManager: UNUserNotificationCenterDelegate {
  
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notifications even when app is in foreground
    completionHandler([.banner, .sound, .badge])
  }
  
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    switch response.actionIdentifier {
    case ActionIdentifiers.openFile:
      handleOpenFile(userInfo: userInfo)
      
    case ActionIdentifiers.retryDownload:
      handleRetryDownload(userInfo: userInfo)
      
    case ActionIdentifiers.dismiss, UNNotificationDefaultActionIdentifier:
      break // Just dismiss
      
    default:
      break
    }
    
    completionHandler()
  }
  
  private func handleOpenFile(userInfo: [AnyHashable: Any]) {
    guard let filePath = userInfo["fileURL"] as? String else { return }
    
    Logger.kit.info("[NOTIFICATIONS] User requested to open file: \(filePath)")
    
    // Post notification for app to handle
    NotificationCenter.default.post(
      name: .openDownloadedFile,
      object: nil,
      userInfo: ["filePath": filePath]
    )
  }
  
  private func handleRetryDownload(userInfo: [AnyHashable: Any]) {
    guard let urlString = userInfo["fileURL"] as? String,
          let url = URL(string: urlString) else { return }
    
    Logger.kit.info("[NOTIFICATIONS] User requested to retry download: \(url)")
    
    // Post notification for app to handle
    NotificationCenter.default.post(
      name: .retryDownload,
      object: nil,
      userInfo: ["url": url]
    )
  }
}

// MARK: - Notification Names
extension Notification.Name {
  static let openDownloadedFile = Notification.Name("openDownloadedFile")
  static let retryDownload = Notification.Name("retryDownload")
}

#endif 