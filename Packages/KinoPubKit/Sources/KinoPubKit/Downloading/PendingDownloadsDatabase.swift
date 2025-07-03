//
//  PendingDownloadsDatabase.swift
//  KinoPubKit
//
//  Created by AI Assistant on 02.07.2025.
//

import Foundation
import KinoPubLogging
import OSLog

/// Протокол для чтения данных о незавершенных загрузках
public protocol PendingDownloadsDataReading {
  associatedtype Meta: Codable & Equatable
  func readPendingDownloads() -> [PendingDownloadInfo<Meta>]
}

/// Протокол для записи данных о незавершенных загрузках
public protocol PendingDownloadsDataWriting {
  associatedtype Meta: Codable & Equatable
  func savePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>)
  func updatePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>)
  func removePendingDownload(for url: URL)
  func clearAllPendingDownloads()
}

/// База данных для управления незавершенными загрузками
public class PendingDownloadsDatabase<Meta: Codable & Equatable>: PendingDownloadsDataReading, PendingDownloadsDataWriting {
  private let fileSaver: FileSaving
  private let dataFileURL: URL

  public init(fileSaver: FileSaving) {
    self.fileSaver = fileSaver
    self.dataFileURL = fileSaver.getDocumentsDirectoryURL(forFilename: "pendingDownloads.plist")
  }

  // MARK: - Reading
  
  public func readPendingDownloads() -> [PendingDownloadInfo<Meta>] {
    Logger.kit.debug("[PENDING] Reading pending downloads from: \(self.dataFileURL.path)")
    
    guard FileManager.default.fileExists(atPath: self.dataFileURL.path) else {
      Logger.kit.debug("[PENDING] Pending downloads file does not exist")
      return []
    }
    
    guard let data = try? Data(contentsOf: self.dataFileURL) else {
      Logger.kit.error("[PENDING] Failed to read data from pending downloads file")
      return []
    }
    
    Logger.kit.debug("[PENDING] Read \(data.count) bytes from pending downloads file")
    
    guard let decodedData = try? PropertyListDecoder().decode([PendingDownloadInfo<Meta>].self, from: data) else {
      Logger.kit.error("[PENDING] Failed to decode pending downloads data")
      return []
    }
    
    Logger.kit.info("[PENDING] Successfully loaded \(decodedData.count) pending downloads")
    for (index, download) in decodedData.enumerated() {
      Logger.kit.debug("[PENDING] Download \(index + 1): \(download.url) - state: \(download.state), progress: \(download.progress)")
    }
    
    return decodedData.sorted(by: { $0.createdAt < $1.createdAt })
  }

  // MARK: - Writing
  
  public func savePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>) {
    Logger.kit.debug("[PENDING] Saving pending download: \(downloadInfo.url)")
    var currentData = readPendingDownloads()
    Logger.kit.debug("[PENDING] Current pending downloads count: \(currentData.count)")
    
    // Удаляем существующую запись для этого URL (если есть)
    let existingCount = currentData.count
    currentData.removeAll { $0.url == downloadInfo.url }
    if currentData.count < existingCount {
      Logger.kit.debug("[PENDING] Removed existing entry for: \(downloadInfo.url)")
    }
    
    // Добавляем новую запись
    currentData.append(downloadInfo)
    Logger.kit.debug("[PENDING] Added pending download, total count: \(currentData.count)")
    
    writeData(currentData)
    Logger.kit.info("[PENDING] Successfully saved pending download: \(downloadInfo.url)")
  }
  
  public func updatePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>) {
    var currentData = readPendingDownloads()
    
    if let index = currentData.firstIndex(where: { $0.url == downloadInfo.url }) {
      currentData[index] = downloadInfo
      writeData(currentData)
      Logger.kit.debug("[PENDING] Updated pending download for: \(downloadInfo.url)")
    } else {
      // Если не найден, сохраняем как новый
      savePendingDownload(downloadInfo)
    }
  }
  
  public func removePendingDownload(for url: URL) {
    var currentData = readPendingDownloads()
    let initialCount = currentData.count
    
    currentData.removeAll { $0.url == url }
    
    if currentData.count != initialCount {
      writeData(currentData)
      Logger.kit.debug("[PENDING] Removed pending download for: \(url)")
    }
  }
  
  public func clearAllPendingDownloads() {
    writeData([])
    Logger.kit.info("[PENDING] Cleared all pending downloads")
  }
  
  // MARK: - Private Methods
  
  private func writeData(_ downloads: [PendingDownloadInfo<Meta>]) {
    Logger.kit.debug("[PENDING] Writing \(downloads.count) pending downloads to file")
    do {
      let data = try PropertyListEncoder().encode(downloads)
      Logger.kit.debug("[PENDING] Encoded \(data.count) bytes of data")
      try data.write(to: self.dataFileURL)
      Logger.kit.debug("[PENDING] Successfully wrote data to: \(self.dataFileURL.path)")
    } catch {
      Logger.kit.error("[PENDING] Failed to write pending downloads: \(error)")
    }
  }
  
  // MARK: - Utility Methods
  
  /// Очищает устаревшие записи (старше указанного количества дней)
  public func cleanupOldPendingDownloads(olderThanDays days: Int = 7) {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    var currentData = readPendingDownloads()
    let initialCount = currentData.count
    
    currentData.removeAll { $0.createdAt < cutoffDate }
    
    if currentData.count != initialCount {
      writeData(currentData)
      Logger.kit.info("[PENDING] Cleaned up \(initialCount - currentData.count) old pending downloads")
    }
  }
  
  /// Возвращает количество незавершенных загрузок
  public func pendingDownloadsCount() -> Int {
    return readPendingDownloads().count
  }
  
  /// Проверяет, есть ли незавершенная загрузка для указанного URL
  public func hasPendingDownload(for url: URL) -> Bool {
    return readPendingDownloads().contains { $0.url == url }
  }
} 