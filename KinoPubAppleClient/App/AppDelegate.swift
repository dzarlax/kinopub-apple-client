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
    
    // Register background tasks
    registerBackgroundTasks()
    
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
    
    // Schedule background tasks if needed
    scheduleBackgroundAppRefresh()
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
  
  // MARK: - Background Task Registration
  private func registerBackgroundTasks() {
    // Register download processing task
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.kinopub.background.downloads",
      using: nil
    ) { task in
      self.handleBackgroundDownloadProcessing(task as! BGProcessingTask)
    }
    
    // Register app refresh task
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.kinopub.background.sync",
      using: nil
    ) { task in
      self.handleBackgroundAppRefresh(task as! BGAppRefreshTask)
    }
    
    Logger.app.info("[APP] Background tasks registered")
  }
  
  private func scheduleBackgroundAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.kinopub.background.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    do {
      try BGTaskScheduler.shared.submit(request)
      Logger.app.info("[APP] Background app refresh scheduled")
    } catch {
      Logger.app.error("[APP] Failed to schedule background app refresh: \(error)")
    }
  }
  
  private func handleBackgroundDownloadProcessing(_ task: BGProcessingTask) {
    Logger.app.info("[APP] Handling background download processing")
    
    // Set expiration handler
    task.expirationHandler = {
      Logger.app.warning("[APP] Background processing task expired")
      task.setTaskCompleted(success: false)
    }
    
    // Perform background work
    Task {
      do {
        // Check and resume downloads
        if let downloadManager = downloadManager {
          Logger.app.debug("[APP] Resuming downloads in background")
          downloadManager.resumeAllDownloads()
        }
        
        // Wait a bit for downloads to process
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        Logger.app.info("[APP] Background processing completed")
        task.setTaskCompleted(success: true)
        
      } catch {
        Logger.app.error("[APP] Background processing failed: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
    
    // Schedule next processing
    scheduleBackgroundDownloadProcessing()
  }
  
  private func handleBackgroundAppRefresh(_ task: BGAppRefreshTask) {
    Logger.app.info("[APP] Handling background app refresh")
    
    task.expirationHandler = {
      Logger.app.warning("[APP] Background app refresh expired")
      task.setTaskCompleted(success: false)
    }
    
    Task {
      // Quick sync operations
      Logger.app.debug("[APP] Performing background sync")
      
      // Schedule next refresh
      scheduleBackgroundAppRefresh()
      
      Logger.app.info("[APP] Background app refresh completed")
      task.setTaskCompleted(success: true)
    }
  }
  
  private func scheduleBackgroundDownloadProcessing() {
    let request = BGProcessingTaskRequest(identifier: "com.kinopub.background.downloads")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds
    
    do {
      try BGTaskScheduler.shared.submit(request)
      Logger.app.info("[APP] Background download processing scheduled")
    } catch {
      Logger.app.error("[APP] Failed to schedule background download processing: \(error)")
    }
  }
  
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
