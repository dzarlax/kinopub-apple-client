//
//  BackgroundTaskManager.swift
//  KinoPubKit
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation
import UIKit
import OSLog
import KinoPubLogging
import BackgroundTasks

#if os(iOS)

// MARK: - Background Task Manager
@available(iOS 13.0, *)
public class BackgroundTaskManager: ObservableObject {
  
  // MARK: - Constants
  private enum TaskIdentifiers {
    static let downloadProcessing = "com.kinopub.background.downloads"
    static let downloadSync = "com.kinopub.background.sync"
  }
  
  // MARK: - Properties
  @Published public private(set) var isBackgroundRefreshAvailable: Bool = false
  @Published public private(set) var backgroundTasksRegistered: Bool = false
  
  private weak var downloadManager: BackgroundDownloadable?
  
  // MARK: - Constants
  public static let downloadTaskIdentifier = "com.kinopub.background-download"
  public static let refreshTaskIdentifier = "com.kinopub.background-refresh"
  
  // MARK: - Future iOS 26 Enhancement
  // TODO: Add BGContinuedProcessingTask support when iOS 26 is released (October 2025)
  // This will allow for longer-running background processing tasks
  // Reference: https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask
  
  // MARK: - Initialization
  public init() {
    checkBackgroundRefreshStatus()
    setupNotifications()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - Public Methods
  public func setDownloadManager<T>(_ manager: DownloadManager<T>) where T: Codable & Equatable {
    self.downloadManager = manager
  }
  
  public func registerBackgroundTasks() {
    guard UIApplication.shared.backgroundRefreshStatus == .available else {
      Logger.kit.warning("[BACKGROUND] Background refresh not available")
      return
    }
    
    // Register processing task for long-running downloads
    let processingRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: TaskIdentifiers.downloadProcessing,
      using: nil
    ) { task in
      self.handleBackgroundDownloadProcessing(task as! BGProcessingTask)
    }
    
    // Register app refresh task for quick sync
    let refreshRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: TaskIdentifiers.downloadSync,
      using: nil
    ) { task in
      self.handleBackgroundDownloadSync(task as! BGAppRefreshTask)
    }
    
    Task { @MainActor in
      self.backgroundTasksRegistered = processingRegistered && refreshRegistered
    }
    
    if backgroundTasksRegistered {
      Logger.kit.info("[BACKGROUND] Background tasks registered successfully")
    } else {
      Logger.kit.error("[BACKGROUND] Failed to register background tasks")
    }
  }
  
  public func scheduleBackgroundDownloadProcessing() {
    let request = BGProcessingTaskRequest(identifier: TaskIdentifiers.downloadProcessing)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds from now
    
    do {
      try BGTaskScheduler.shared.submit(request)
      Logger.kit.info("[BACKGROUND] Background processing task scheduled")
    } catch {
      Logger.kit.error("[BACKGROUND] Failed to schedule background processing: \(error)")
    }
  }
  
  public func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: TaskIdentifiers.downloadSync)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute from now
    
    do {
      try BGTaskScheduler.shared.submit(request)
      Logger.kit.info("[BACKGROUND] Background sync task scheduled")
    } catch {
      Logger.kit.error("[BACKGROUND] Failed to schedule background sync: \(error)")
    }
  }
  
  // MARK: - Private Methods
  private func checkBackgroundRefreshStatus() {
    isBackgroundRefreshAvailable = UIApplication.shared.backgroundRefreshStatus == .available
    
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available:
      Logger.kit.info("[BACKGROUND] Background refresh available")
    case .denied:
      Logger.kit.warning("[BACKGROUND] Background refresh denied by user")
    case .restricted:
      Logger.kit.warning("[BACKGROUND] Background refresh restricted")
    @unknown default:
      Logger.kit.warning("[BACKGROUND] Unknown background refresh status")
    }
  }
  
  private func setupNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(backgroundRefreshStatusDidChange),
      name: UIApplication.backgroundRefreshStatusDidChangeNotification,
      object: nil
    )
  }
  
  @objc private func backgroundRefreshStatusDidChange() {
    DispatchQueue.main.async {
      self.checkBackgroundRefreshStatus()
    }
  }
  
  // MARK: - Background Task Handlers
  private func handleBackgroundDownloadProcessing(_ task: BGProcessingTask) {
    Logger.kit.info("[BACKGROUND] Handling background download processing")
    
    // Schedule next processing task
    scheduleBackgroundDownloadProcessing()
    
    task.expirationHandler = {
      Logger.kit.warning("[BACKGROUND] Background processing task expired")
      task.setTaskCompleted(success: false)
    }
    
    // Perform background work
    Task {
      do {
        // Check and resume any paused downloads
        await resumePendingDownloads()
        
        // Check available storage
        try await validateStorageSpace()
        
        // Notify about completed downloads
        await sendDownloadNotifications()
        
        Logger.kit.info("[BACKGROUND] Background processing completed successfully")
        task.setTaskCompleted(success: true)
        
      } catch {
        Logger.kit.error("[BACKGROUND] Background processing failed: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
  }
  
  private func handleBackgroundDownloadSync(_ task: BGAppRefreshTask) {
    Logger.kit.info("[BACKGROUND] Handling background download sync")
    
    // Schedule next sync
    scheduleBackgroundSync()
    
    task.expirationHandler = {
      Logger.kit.warning("[BACKGROUND] Background sync task expired")
      task.setTaskCompleted(success: false)
    }
    
    Task {
      do {
        // Quick sync of download states
        await syncDownloadStates()
        
        Logger.kit.info("[BACKGROUND] Background sync completed")
        task.setTaskCompleted(success: true)
        
      } catch {
        Logger.kit.error("[BACKGROUND] Background sync failed: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
  }
  
  private func resumePendingDownloads() async {
    guard let downloadManager = downloadManager else { return }
    
    Logger.kit.debug("[BACKGROUND] Resuming pending downloads")
    downloadManager.resumeAllDownloads()
  }
  
  private func validateStorageSpace() async throws {
    let fileManager = FileManager.default
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    
    guard let documentsURL = documentsPath else {
      throw BackgroundTaskError.storageValidationFailed
    }
    
    let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    
    if let availableCapacity = resourceValues.volumeAvailableCapacity,
       availableCapacity < 100_000_000 { // Less than 100MB
      Logger.kit.warning("[BACKGROUND] Low storage space detected: \(availableCapacity) bytes")
      // Could pause non-critical downloads here
    }
  }
  
  private func syncDownloadStates() async {
    // Sync download progress and states
    Logger.kit.debug("[BACKGROUND] Syncing download states")
  }
  
  private func sendDownloadNotifications() async {
    // Send notifications for completed downloads
    Logger.kit.debug("[BACKGROUND] Checking for download completion notifications")
  }
}

// MARK: - Background Task Errors
enum BackgroundTaskError: LocalizedError {
  case storageValidationFailed
  case downloadManagerNotSet
  
  var errorDescription: String? {
    switch self {
    case .storageValidationFailed:
      return "Failed to validate storage space"
    case .downloadManagerNotSet:
      return "Download manager not configured"
    }
  }
}

#endif 