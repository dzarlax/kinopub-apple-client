//
//  Download.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import KinoPubLogging
import OSLog

/// `Download` represents a downloadable resource. It provides methods for controlling the download,
/// such as pausing and resuming, and notifies about the progress through a progress handler.
public class Download<Meta: Codable & Equatable>: ObservableObject {
  /// The state of the download, such as not started, queued, in progress, or paused.
  public enum State: String {
    case notStarted
    case queued
    case inProgress
    case paused
  }
  
  /// URL for the download
  public let url: URL
  
  /// The current state of the download.
  public private(set) var state: State = .notStarted
  
  /// Progress value
  @Published public private(set) var progress: Float = 0.0
  
  /// Public metadata
  public let metadata: Meta
  
  // - Internal
  internal var task: URLSessionDownloadTask?
  
  private var resumeData: Data?
  
  private let manager: any DownloadManaging
  
  /// Initializes a `Download` object.
  /// - Parameters:
  ///   - url: The URL of the resource to be downloaded.
  ///   - metadata: Metadata associated with the download.
  ///   - manager: An object that conforms to `DownloadManaging` to manage the download session.
  public init(url: URL, metadata: Meta, manager: any DownloadManaging) {
    self.url = url
    self.metadata = metadata
    self.manager = manager
    self.state = .queued
    Logger.kit.debug("[DOWNLOAD] Download for url: \(url) is queued")
  }
  
  /// Pauses the download. If the download is already paused or not in progress, this method has no effect.
  public func pause() {
    Logger.kit.info("[DOWNLOAD] Pausing download for: \(self.url)")
    
    guard let task = self.task else {
      Logger.kit.warning("[DOWNLOAD] No task to pause for: \(self.url)")
      return
    }
    
    task.cancel(byProducingResumeData: { [weak self] data in
      guard let self = self else { return }
      
      Logger.kit.debug("[DOWNLOAD] Received resume data for: \(self.url)")
      if let data = data {
        Logger.kit.debug("[DOWNLOAD] Resume data size: \(data.count) bytes")
        self.resumeData = data
      } else {
        Logger.kit.warning("[DOWNLOAD] No resume data received for: \(self.url)")
      }
      
      self.state = .paused
      
      // Уведомляем менеджер о паузе с resumeData
      if let downloadManager = self.manager as? DownloadManager<Meta> {
        Logger.kit.debug("[DOWNLOAD] Updating pending download on pause for: \(self.url)")
        downloadManager.updatePendingDownloadOnPause(url: self.url, resumeData: data, progress: self.progress)
      } else {
        Logger.kit.error("[DOWNLOAD] Manager is not DownloadManager type")
      }
      
      Logger.kit.info("[DOWNLOAD] Download paused for: \(self.url), progress: \(self.progress)")
    })
    self.task = nil
  }
  
  /// Resumes the download. If the download is already in progress, this method has no effect.
  public func resume() {
    if let resumeData = self.resumeData {
      task = manager.session.downloadTask(withResumeData: resumeData)
    } else {
      task = manager.session.downloadTask(with: URLRequest(url: url))
    }
    state = .inProgress
    Logger.kit.debug("[DOWNLOAD] Download for url: \(self.url) is in progress")
    task?.resume()
  }
  
  internal func updateProgress(_ progress: Float) {
    self.progress = progress
  }
  
  /// Устанавливает данные для возобновления загрузки
  internal func setResumeData(_ data: Data) {
    self.resumeData = data
  }
  
  /// Получает данные для возобновления загрузки
  internal func getResumeData() -> Data? {
    return resumeData
  }
  
}

extension Download: Identifiable {}
