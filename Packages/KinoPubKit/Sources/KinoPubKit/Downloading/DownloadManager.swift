//
//  DownloadManager.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import OSLog
import KinoPubLogging
import Combine

#if os(iOS)
import UIKit
import BackgroundTasks
#endif

public protocol DownloadManaging {
  associatedtype Meta: Codable & Equatable
  
  var session: URLSession { get }
  var activeDownloads: [URL: Download<Meta>] { get }
  
  func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta>
  func removeDownload(for url: URL)
  func completeDownload(_ url: URL)
  func pauseAllDownloads()
  func resumeAllDownloads()
}

public class DownloadManager<Meta: Codable & Equatable>: NSObject, URLSessionDownloadDelegate, DownloadManaging, ObservableObject {
  
  // MARK: - Published Properties
  @Published public private(set) var activeDownloads: [URL: Download<Meta>] = [:]
  @Published public private(set) var downloadProgress: [URL: Float] = [:]
  @Published public private(set) var backgroundDownloadsEnabled: Bool = false
  
  // MARK: - Private Properties
  private let fileSaver: FileSaving
  private let database: DownloadedFilesDatabase<Meta>
  private let downloadQueue = DispatchQueue(label: "com.kinopub.downloads", qos: .utility)
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Background Support
  #if os(iOS)
  @available(iOS 13.0, *)
  public private(set) lazy var backgroundTaskManager = BackgroundTaskManager()
  
  @available(iOS 10.0, *)
  public private(set) lazy var notificationManager = DownloadNotificationManager()
  #endif
  
  // MARK: - Configuration
  private let maxConcurrentDownloads: Int
  private let timeoutInterval: TimeInterval
  private var backgroundSessionIdentifier: String
  
  // MARK: - Background Completion Handler
  #if os(iOS)
  public var backgroundCompletionHandler: (() -> Void)?
  #endif

  public init(
    fileSaver: FileSaving, 
    database: DownloadedFilesDatabase<Meta>,
    maxConcurrentDownloads: Int = 3,
    timeoutInterval: TimeInterval = 60.0,
    backgroundSessionIdentifier: String = "com.kinopub.backgroundDownloadSession"
  ) {
    self.fileSaver = fileSaver
    self.database = database
    self.maxConcurrentDownloads = maxConcurrentDownloads
    self.timeoutInterval = timeoutInterval
    self.backgroundSessionIdentifier = backgroundSessionIdentifier
    super.init()
    
    setupNotifications()
    setupBackgroundSupport()
  }

  // MARK: - Lazy Session
  lazy public var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
    config.timeoutIntervalForRequest = timeoutInterval
    config.httpMaximumConnectionsPerHost = maxConcurrentDownloads
    config.allowsCellularAccess = true
    config.allowsExpensiveNetworkAccess = true
    config.allowsConstrainedNetworkAccess = false
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false // High priority downloads
    
    // Enhanced background configuration
    config.shouldUseExtendedBackgroundIdleMode = true
    
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  // MARK: - Public Methods
  public func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta> {
    return downloadQueue.sync {
      // Check if download already exists
      if let existingDownload = activeDownloads[url] {
        Logger.kit.info("[DOWNLOAD] Download already exists for: \(url)")
        return existingDownload
      }
      
      // Check concurrent download limit
      if activeDownloads.count >= maxConcurrentDownloads {
        Logger.kit.warning("[DOWNLOAD] Maximum concurrent downloads reached. Queuing: \(url)")
      }
      
      let download = Download(url: url, metadata: metadata, manager: self)
      activeDownloads[url] = download
      downloadProgress[url] = 0.0
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      download.resume()
      Logger.kit.info("[DOWNLOAD] Started download for: \(url)")
      
      // Schedule background processing if needed
      #if os(iOS)
      if backgroundDownloadsEnabled {
        if #available(iOS 13.0, *) {
          backgroundTaskManager.scheduleBackgroundDownloadProcessing()
        }
      }
      #endif
      
      return download
    }
  }
  
  public func removeDownload(for url: URL) {
    downloadQueue.async { [weak self] in
      guard let self = self,
            let download = self.activeDownloads[url] else {
        return
      }
      
      download.pause()
      self.activeDownloads.removeValue(forKey: url)
      self.downloadProgress.removeValue(forKey: url)
      
      #if os(iOS)
      if #available(iOS 10.0, *) {
        self.notificationManager.clearNotifications(for: url)
      }
      #endif
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      Logger.kit.info("[DOWNLOAD] Removed download for: \(url)")
    }
  }

  public func completeDownload(_ url: URL) {
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      self.activeDownloads.removeValue(forKey: url)
      self.downloadProgress.removeValue(forKey: url)
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      Logger.kit.info("[DOWNLOAD] Completed download for: \(url)")
    }
  }
  
  public func pauseAllDownloads() {
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      self.activeDownloads.values.forEach { $0.pause() }
      Logger.kit.info("[DOWNLOAD] Paused all downloads")
    }
  }
  
  public func resumeAllDownloads() {
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      self.activeDownloads.values.forEach { $0.resume() }
      Logger.kit.info("[DOWNLOAD] Resumed all downloads")
    }
  }
  
  // MARK: - Background Support Methods
  public func enableBackgroundDownloads() async -> Bool {
    #if os(iOS)
    guard #available(iOS 13.0, *) else {
      Logger.kit.warning("[DOWNLOAD] Background downloads require iOS 13.0+")
      return false
    }
    
    // Request notification permission
    if #available(iOS 10.0, *) {
      let notificationGranted = await notificationManager.requestNotificationPermission()
      if !notificationGranted {
        Logger.kit.warning("[DOWNLOAD] Notification permission not granted")
      }
    }
    
    // Register background tasks
    backgroundTaskManager.registerBackgroundTasks()
    backgroundTaskManager.setDownloadManager(self)
    
    await MainActor.run {
      self.backgroundDownloadsEnabled = true
    }
    
    Logger.kit.info("[DOWNLOAD] Background downloads enabled")
    return true
    #else
    return false
    #endif
  }
  
  public func handleBackgroundURLSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
    #if os(iOS)
    guard identifier == backgroundSessionIdentifier else {
      completionHandler()
      return
    }
    
    backgroundCompletionHandler = completionHandler
    Logger.kit.info("[DOWNLOAD] Handling background URL session events")
    #else
    completionHandler()
    #endif
  }

  // MARK: - Private Methods
  private func setupNotifications() {
    NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
      .sink { [weak self] _ in
        self?.handlePowerStateChange()
      }
      .store(in: &cancellables)
    
    #if os(iOS)
    NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
      .sink { [weak self] _ in
        self?.handleAppDidEnterBackground()
      }
      .store(in: &cancellables)
    
    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
      .sink { [weak self] _ in
        self?.handleAppWillEnterForeground()
      }
      .store(in: &cancellables)
    #endif
  }
  
  private func setupBackgroundSupport() {
    #if os(iOS)
    // Check if background app refresh is available
    backgroundDownloadsEnabled = UIApplication.shared.backgroundRefreshStatus == .available
    
    if backgroundDownloadsEnabled {
      Logger.kit.info("[DOWNLOAD] Background app refresh is available")
    } else {
      Logger.kit.warning("[DOWNLOAD] Background app refresh is not available")
    }
    #endif
  }
  
  private func handlePowerStateChange() {
    if ProcessInfo.processInfo.isLowPowerModeEnabled {
      pauseAllDownloads()
      Logger.kit.info("[DOWNLOAD] Low power mode enabled, pausing downloads")
    } else {
      resumeAllDownloads()
      Logger.kit.info("[DOWNLOAD] Low power mode disabled, resuming downloads")
    }
  }
  
  #if os(iOS)
  private func handleAppDidEnterBackground() {
    Logger.kit.info("[DOWNLOAD] App entered background, background downloads will continue")
    
    if backgroundDownloadsEnabled {
      if #available(iOS 13.0, *) {
        backgroundTaskManager.scheduleBackgroundDownloadProcessing()
      }
    }
  }
  
  private func handleAppWillEnterForeground() {
    Logger.kit.info("[DOWNLOAD] App entering foreground, syncing download states")
    
    // Refresh download states
    session.getAllTasks { tasks in
      Logger.kit.debug("[DOWNLOAD] Found \(tasks.count) active background tasks")
    }
  }
  #endif

  // MARK: - URLSessionDownloadDelegate
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let sourceURL = downloadTask.originalRequest?.url, 
          let download = activeDownloads[sourceURL] else { 
      Logger.kit.error("[DOWNLOAD] No download found for completed task")
      return 
    }
    
    Logger.kit.debug("[DOWNLOAD] Download finished: \(location)")

    let destinationURL = fileSaver.getDocumentsDirectoryURL(forFilename: sourceURL.lastPathComponent)

    do {
      try fileSaver.saveFile(from: location, to: destinationURL)
      Logger.kit.info("[DOWNLOAD] File: \(location) moved to documents folder")

      let fileInfo = DownloadedFileInfo(
        originalURL: sourceURL, 
        localFilename: sourceURL.lastPathComponent, 
        downloadDate: Date(), 
        metadata: download.metadata
      )
      
      database.save(fileInfo: fileInfo)
      
      // Send notification
      #if os(iOS)
      if #available(iOS 10.0, *), backgroundDownloadsEnabled {
        notificationManager.scheduleDownloadCompleteNotification(
          for: fileInfo,
          localURL: destinationURL
        )
      }
      #endif
      
      // Post notification for UI updates
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: .downloadCompleted, 
          object: nil, 
          userInfo: ["url": sourceURL, "fileInfo": fileInfo]
        )
      }
      
    } catch {
      Logger.kit.error("[DOWNLOAD] Error during moving file: \(error)")
      
      #if os(iOS)
      if #available(iOS 10.0, *), backgroundDownloadsEnabled {
        notificationManager.scheduleDownloadFailedNotification(
          for: sourceURL,
          fileName: sourceURL.lastPathComponent,
          error: error
        )
      }
      #endif
      
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: .downloadFailed, 
          object: nil, 
          userInfo: ["url": sourceURL, "error": error]
        )
      }
    }

    completeDownload(sourceURL)
  }

  public func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
    
    guard totalBytesExpectedToWrite > 0,
          let url = downloadTask.originalRequest?.url,
          let download = activeDownloads[url] else { return }
    
    let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    Logger.kit.debug("[DOWNLOAD] Progress for \(url): \(progress)")
    
    downloadQueue.async { [weak self] in
      self?.downloadProgress[url] = progress
    }
    
    DispatchQueue.main.async { [weak self] in
      download.updateProgress(progress)
      self?.objectWillChange.send()
    }
    
    // Send progress notification
    #if os(iOS)
    if #available(iOS 10.0, *), backgroundDownloadsEnabled {
      notificationManager.scheduleProgressNotification(
        for: url.lastPathComponent,
        progress: progress,
        url: url
      )
    }
    #endif
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let url = task.originalRequest?.url else { return }
    
    if let error = error {
      Logger.kit.error("[DOWNLOAD] Download error for \(url): \(error)")
      
      #if os(iOS)
      if #available(iOS 10.0, *), backgroundDownloadsEnabled {
        notificationManager.scheduleDownloadFailedNotification(
          for: url,
          fileName: url.lastPathComponent,
          error: error
        )
      }
      #endif
      
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: .downloadFailed, 
          object: nil, 
          userInfo: ["url": url, "error": error]
        )
      }
    }
    
    completeDownload(url)
  }
  
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    Logger.kit.info("[DOWNLOAD] Background URL session finished events")
    
    #if os(iOS)
    DispatchQueue.main.async { [weak self] in
      self?.backgroundCompletionHandler?()
      self?.backgroundCompletionHandler = nil
    }
    #endif
  }
}

// MARK: - Notification Names
extension Notification.Name {
  static let downloadCompleted = Notification.Name("downloadCompleted")
  static let downloadFailed = Notification.Name("downloadFailed")
  static let downloadProgress = Notification.Name("downloadProgress")
}
