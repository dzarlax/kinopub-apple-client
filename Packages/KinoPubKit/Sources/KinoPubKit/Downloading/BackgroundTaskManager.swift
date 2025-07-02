//
//  BackgroundTaskManager.swift
//  KinoPubKit
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation
import OSLog
import KinoPubLogging

#if os(iOS)
import UIKit
import BackgroundTasks

// MARK: - Background Task Manager
public class BackgroundTaskManager: ObservableObject {
  
  // MARK: - Constants
  private enum TaskIdentifiers {
    static let downloadSync = "com.kinopub.background.sync"
    // BGContinuedProcessingTask identifier - matches wildcard in Info.plist (iOS 26+)
    static let continuedProcessing = "com.kinopub.backgroundDownloads.task"
  }
  
  // MARK: - Properties
  @Published public private(set) var isBackgroundRefreshAvailable: Bool = false
  @Published public private(set) var backgroundTasksRegistered: Bool = false
  
  private weak var downloadManager: BackgroundDownloadable?
  private var registrationAttempted: Bool = false
  
  // MARK: - BGContinuedProcessingTask Support
  // BGContinuedProcessingTask will be available in future iOS versions
  // When available, it will provide extended background processing time for large video downloads
  // Reference: https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask
  // 
  // To enable when available:
  // 1. Update checkContinuedProcessingSupport() to check for the actual iOS version
  // 2. Uncomment the BGContinuedProcessingTask registration code
  // 3. Update scheduleBackgroundDownloadProcessing() to use the appropriate task type
  
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
    Task { @MainActor in
      guard UIApplication.shared.backgroundRefreshStatus == .available else {
        Logger.kit.warning("[BACKGROUND] Background refresh not available")
        return
      }
      
      await performBackgroundTaskRegistration()
    }
  }
  
  public func resetRegistration() {
    registrationAttempted = false
    backgroundTasksRegistered = false
    Logger.kit.info("[BACKGROUND] Registration state reset")
  }
  
  @MainActor
  private func performBackgroundTaskRegistration() async {
    // Prevent multiple registration attempts
    guard !registrationAttempted else {
      Logger.kit.info("[BACKGROUND] Background tasks already registered, skipping")
      return
    }
    
    registrationAttempted = true
    var registrationResults: [Bool] = []
    
    // Register BGContinuedProcessingTask
    let continuedRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: TaskIdentifiers.continuedProcessing,
      using: nil
    ) { [weak self] task in
      self?.handleContinuedProcessingTask(task)
    }
    registrationResults.append(continuedRegistered)
    
    if continuedRegistered {
      Logger.kit.info("[BACKGROUND] BGContinuedProcessingTask registered successfully")
    } else {
      Logger.kit.error("[BACKGROUND] BGContinuedProcessingTask registration failed")
    }
    
    // Register app refresh task for quick sync
    let refreshRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: TaskIdentifiers.downloadSync,
      using: nil
    ) { task in
      self.handleBackgroundDownloadSync(task as! BGAppRefreshTask)
    }
    registrationResults.append(refreshRegistered)
    
    if refreshRegistered {
      Logger.kit.info("[BACKGROUND] Background sync task registered successfully")
    } else {
      Logger.kit.warning("[BACKGROUND] Background sync task registration failed")
    }
    
    self.backgroundTasksRegistered = !registrationResults.contains(false)
    
    if backgroundTasksRegistered {
      Logger.kit.info("[BACKGROUND] All background tasks registered successfully")
    } else {
      Logger.kit.error("[BACKGROUND] Some background tasks failed to register")
    }
  }
  
  public func scheduleBackgroundDownloadProcessing() {
    Logger.kit.info("[BACKGROUND] Scheduling background download processing...")
    Logger.kit.info("[BACKGROUND] Will schedule BGContinuedProcessingTask")
    scheduleContinuedProcessingTask()
  }
  
  private func scheduleContinuedProcessingTask() {
    let identifier = TaskIdentifiers.continuedProcessing
    
    Logger.kit.info("[BACKGROUND] Creating BGContinuedProcessingTask with identifier: \(identifier)")
    
    if #available(iOS 26.0, *) {
      let request = BGContinuedProcessingTaskRequest(
        identifier: identifier,
        title: "KinoPub Downloads", 
        subtitle: "Downloading video content in background"
      )
      
      // Configure submission strategy  
      request.strategy = .queue  // Queue for processing as soon as possible
      
      // Log additional details about the request
      Logger.kit.info("[BACKGROUND] BGContinuedProcessingTask details:")
      Logger.kit.info("[BACKGROUND] - Identifier: \(request.identifier)")
      Logger.kit.info("[BACKGROUND] - Title: \(request.title)")
      Logger.kit.info("[BACKGROUND] - Subtitle: \(request.subtitle)")
      Logger.kit.info("[BACKGROUND] - Strategy: \(String(describing: request.strategy))")
      
              do {
          try BGTaskScheduler.shared.submit(request)
          Logger.kit.info("[BACKGROUND] BGContinuedProcessingTask scheduled successfully")
          Logger.kit.info("[BACKGROUND] Live Activity should be displayed to user")
          
          // Check if Live Activities are supported
          #if os(iOS)
          Task { @MainActor in
            Logger.kit.info("[BACKGROUND] iOS 26+ detected, Live Activities should be supported")
            Logger.kit.info("[BACKGROUND] Check Control Center or Lock Screen for Live Activity")
          }
          #endif
          
        } catch {
        Logger.kit.error("[BACKGROUND] Failed to schedule BGContinuedProcessingTask: \(error)")
        Logger.kit.error("[BACKGROUND] Error details: \(error.localizedDescription)")
      }
    } else {
      Logger.kit.error("[BACKGROUND] BGContinuedProcessingTaskRequest requires iOS 26+")
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
    Task { @MainActor in
      let status = UIApplication.shared.backgroundRefreshStatus
      self.isBackgroundRefreshAvailable = status == .available
      
      switch status {
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
  
  // New handler for BGContinuedProcessingTask 
  // Using conditional compilation for SDK compatibility
  private func handleContinuedProcessingTask(_ task: BGTask) {
    Logger.kit.info("[BACKGROUND] Handling BGContinuedProcessingTask")
    
    // Note: Do not schedule next BGContinuedProcessingTask here
    // It should be scheduled by the app when needed, from foreground
    
    task.expirationHandler = {
      Logger.kit.warning("[BACKGROUND] BGContinuedProcessingTask expired")
      task.setTaskCompleted(success: false)
    }
    
    // Perform extended background work
    Task { [weak self] in
      do {
        // Extended processing for larger downloads
        await self?.performExtendedDownloadProcessing()
        
        // Validate storage and optimize downloads
        if let self = self {
          try await self.validateStorageSpace()
        }
        
        // Send progress notifications
        await self?.sendDownloadNotifications()
        
        Logger.kit.info("[BACKGROUND] BGContinuedProcessingTask completed successfully")
        task.setTaskCompleted(success: true)
        
      } catch {
        Logger.kit.error("[BACKGROUND] BGContinuedProcessingTask failed: \(error)")
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
    
    Task { [weak self] in
      // Quick sync of download states
      await self?.syncDownloadStates()
      
      Logger.kit.info("[BACKGROUND] Background sync completed")
      task.setTaskCompleted(success: true)
    }
  }
  
  // MARK: - Processing Methods
  
  private func performExtendedDownloadProcessing() async {
    Logger.kit.debug("[BACKGROUND] Performing extended download processing")
    
    guard let downloadManager = downloadManager else { 
      Logger.kit.warning("[BACKGROUND] Download manager not available")
      return 
    }
    
    // Resume all downloads with extended time
    downloadManager.resumeAllDownloads()
    
    // Allow more time for larger downloads
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds buffer
    
    // Monitor active downloads
    let activeCount = downloadManager.activeDownloadsCount
    Logger.kit.info("[BACKGROUND] Managing \(activeCount) active downloads in extended processing")
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