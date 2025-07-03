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
  private let pendingDownloadsDatabase: PendingDownloadsDatabase<Meta>
  private let downloadQueue = DispatchQueue(label: "com.kinopub.downloads", qos: .utility)
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Background Support
  #if os(iOS)
  public private(set) lazy var backgroundTaskManager = BackgroundTaskManager()
  
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
    self.pendingDownloadsDatabase = PendingDownloadsDatabase(fileSaver: fileSaver)
    self.maxConcurrentDownloads = maxConcurrentDownloads
    self.timeoutInterval = timeoutInterval
    self.backgroundSessionIdentifier = backgroundSessionIdentifier
    super.init()
    
    setupNotifications()
    setupBackgroundSupport()
    
    // Восстанавливаем незавершенные загрузки при инициализации
    restorePendingDownloads()
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
      
      // Сохраняем информацию о незавершенной загрузке
      let pendingDownload = PendingDownloadInfo(url: url, metadata: metadata, state: "started")
      pendingDownloadsDatabase.savePendingDownload(pendingDownload)
      Logger.kit.info("[DOWNLOAD] Saved pending download info for: \(url)")
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      download.resume()
      Logger.kit.info("[DOWNLOAD] Started download for: \(url)")
      
      // Schedule background processing if needed
      #if os(iOS)
      if backgroundDownloadsEnabled {
        backgroundTaskManager.scheduleBackgroundDownloadProcessing()
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
      
      // Удаляем из базы незавершенных загрузок
      self.pendingDownloadsDatabase.removePendingDownload(for: url)
      
      #if os(iOS)
      self.notificationManager.clearNotifications(for: url)
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
      
      // Удаляем из базы незавершенных загрузок при успешном завершении
      self.pendingDownloadsDatabase.removePendingDownload(for: url)
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      Logger.kit.info("[DOWNLOAD] Completed download for: \(url)")
    }
  }
  
  public func pauseAllDownloads() {
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      for download in self.activeDownloads.values {
        download.pause()
        // Состояние будет обновлено в методе pause() через updatePendingDownloadOnPause
      }
      
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
    // Check if already enabled to prevent duplicate registration
    if backgroundDownloadsEnabled && backgroundTaskManager.backgroundTasksRegistered {
      Logger.kit.info("[DOWNLOAD] Background downloads already enabled")
      return true
    }
    
    // Request notification permission
    let notificationGranted = await notificationManager.requestNotificationPermission()
    if !notificationGranted {
      Logger.kit.warning("[DOWNLOAD] Notification permission not granted")
    }
    
    // Register background tasks (only if not already registered)
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
    
    // Сохраняем состояние всех активных загрузок
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      for (url, download) in self.activeDownloads {
        let progress = self.downloadProgress[url] ?? 0.0
        let resumeData = download.getResumeData()
        self.updatePendingDownload(url: url, resumeData: resumeData, progress: progress, state: "background")
      }
    }
    
    if backgroundDownloadsEnabled {
      backgroundTaskManager.scheduleBackgroundDownloadProcessing()
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

  // MARK: - Pending Downloads Management
  
  /// Восстанавливает незавершенные загрузки после перезапуска приложения
  private func restorePendingDownloads() {
    downloadQueue.async { [weak self] in
      guard let self = self else { return }
      
      let pendingDownloads = self.pendingDownloadsDatabase.readPendingDownloads()
      if pendingDownloads.count > 0 {
        Logger.kit.info("[DOWNLOAD] Restoring \(pendingDownloads.count) pending downloads")
      }
      
      for pendingDownload in pendingDownloads {
        // Проверяем, не активна ли уже эта загрузка
        if self.activeDownloads[pendingDownload.url] != nil {
          continue
        }
        
        let download = Download(url: pendingDownload.url, metadata: pendingDownload.metadata, manager: self)
        
        // Восстанавливаем resumeData если есть
        if let resumeData = pendingDownload.resumeData {
          download.setResumeData(resumeData)
        }
        
        self.activeDownloads[pendingDownload.url] = download
        self.downloadProgress[pendingDownload.url] = pendingDownload.progress
        
        // Автоматически возобновляем загрузку
        download.resume()
      }
      
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
      
      // Очищаем старые записи
      self.pendingDownloadsDatabase.cleanupOldPendingDownloads()
      Logger.kit.info("[DOWNLOAD] Finished restoring pending downloads")
    }
  }
  
  /// Обновляет информацию о незавершенной загрузке
  private func updatePendingDownload(url: URL, resumeData: Data?, progress: Float, state: String) {
    guard let download = activeDownloads[url] else { return }
    
    let updatedPendingDownload = PendingDownloadInfo(
      url: url, 
      metadata: download.metadata, 
      resumeData: resumeData, 
      progress: progress, 
      state: state
    )
    
    pendingDownloadsDatabase.updatePendingDownload(updatedPendingDownload)
  }
  
  /// Получает количество незавершенных загрузок
  public func pendingDownloadsCount() -> Int {
    return pendingDownloadsDatabase.pendingDownloadsCount()
  }
  
  /// Очищает все незавершенные загрузки
  public func clearAllPendingDownloads() {
    pendingDownloadsDatabase.clearAllPendingDownloads()
  }
  
  /// Обновляет незавершенную загрузку при паузе (вызывается из Download)
  internal func updatePendingDownloadOnPause(url: URL, resumeData: Data?, progress: Float) {
    updatePendingDownload(url: url, resumeData: resumeData, progress: progress, state: "paused")
  }
  
  /// Получает доступ к базе данных загруженных файлов (для SeasonDownloadManager)
  public func getDownloadedFiles() -> [DownloadedFileInfo<Meta>]? {
    return database.readData()
  }

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
      if backgroundDownloadsEnabled {
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
      if backgroundDownloadsEnabled {
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
      
      // Обновляем информацию о незавершенной загрузке
      self?.updatePendingDownload(url: url, resumeData: nil, progress: progress, state: "downloading")
    }
    
    DispatchQueue.main.async { [weak self] in
      download.updateProgress(progress)
      self?.objectWillChange.send()
    }
    
    // Send progress notification
    #if os(iOS)
    if backgroundDownloadsEnabled {
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
      if backgroundDownloadsEnabled {
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
