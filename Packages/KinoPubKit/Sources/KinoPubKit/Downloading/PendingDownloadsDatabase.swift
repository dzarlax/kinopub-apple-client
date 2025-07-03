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
    guard FileManager.default.fileExists(atPath: self.dataFileURL.path) else {
      return []
    }
    
    guard let data = try? Data(contentsOf: self.dataFileURL) else {
      Logger.kit.error("[PENDING] Failed to read data from pending downloads file")
      return []
    }
    
    guard let decodedData = try? PropertyListDecoder().decode([PendingDownloadInfo<Meta>].self, from: data) else {
      Logger.kit.error("[PENDING] Failed to decode pending downloads data")
      return []
    }
    
    return decodedData.sorted(by: { $0.createdAt < $1.createdAt })
  }

  // MARK: - Writing
  
  public func savePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>) {
    var currentData = readPendingDownloads()
    
    // Удаляем существующую запись для этого URL (если есть)
    currentData.removeAll { $0.url == downloadInfo.url }
    
    // Добавляем новую запись
    currentData.append(downloadInfo)
    
    writeData(currentData)
  }
  
  public func updatePendingDownload(_ downloadInfo: PendingDownloadInfo<Meta>) {
    var currentData = readPendingDownloads()
    
    if let index = currentData.firstIndex(where: { $0.url == downloadInfo.url }) {
      currentData[index] = downloadInfo
      writeData(currentData)
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
    }
  }
  
  public func clearAllPendingDownloads() {
    writeData([])
  }
  
  // MARK: - Private Methods
  
  private func writeData(_ downloads: [PendingDownloadInfo<Meta>]) {
    do {
      let data = try PropertyListEncoder().encode(downloads)
      try data.write(to: self.dataFileURL)
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