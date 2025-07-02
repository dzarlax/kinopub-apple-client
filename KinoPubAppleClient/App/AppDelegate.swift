//
//  AppDelegate.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubKit
import KinoPubLogging
import OSLog
import UserNotifications

#if os(iOS)
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
  
  // This flag is used to lock orientation on the player view
  static var orientationLock = UIInterfaceOrientationMask.all
  
  // Background download support
  private var downloadManager: DownloadManager<DownloadMeta>?
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    
    // Background tasks are now handled by BackgroundTaskManager in DownloadManager
    // registerBackgroundTasks() // Removed to prevent duplicate registration
    
    Logger.app.info("[APP] Application did finish launching")
    return true
  }
  
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
  
  // MARK: - Background Downloads Support
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
    Logger.app.info("[APP] Handling background URL session events for: \(identifier)")
    
    // Delegate to download manager
    downloadManager?.handleBackgroundURLSessionEvents(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    Logger.app.info("[APP] Application entered background")
    
    // Background task scheduling is now handled by BackgroundTaskManager
  }
  
  func applicationWillEnterForeground(_ application: UIApplication) {
    Logger.app.info("[APP] Application will enter foreground")
    
    // Clear notification badge
    UNUserNotificationCenter.current().setBadgeCount(0) { error in
      if let error = error {
        Logger.app.error("[APP] Failed to clear badge count: \(error)")
      }
    }
  }
  
  // MARK: - Background Tasks
  // Background task registration and handling is now managed by BackgroundTaskManager
  // This provides better support for BGContinuedProcessingTask and unified task management
  
  // MARK: - Download Manager Injection
  func setDownloadManager(_ manager: DownloadManager<DownloadMeta>) {
    self.downloadManager = manager
    Logger.app.info("[APP] Download manager configured for background support")
  }
}
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    Logger.app.info("[APP] macOS application did finish launching")
  }
  
  func applicationWillTerminate(_ notification: Notification) {
    Logger.app.info("[APP] macOS application will terminate")
  }
  
  func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
    return true
  }
}
#endif
