//
//  PendingDownloadInfo.swift
//  KinoPubKit
//
//  Created by AI Assistant on 02.07.2025.
//

import Foundation

/// PendingDownloadInfo содержит информацию о незавершенной загрузке
/// для возобновления после перезапуска приложения
public struct PendingDownloadInfo<Meta: Codable & Equatable>: Codable {
  /// URL загружаемого файла
  public let url: URL
  
  /// Метаданные, связанные с загрузкой
  public let metadata: Meta
  
  /// Данные для возобновления загрузки (если есть)
  public let resumeData: Data?
  
  /// Прогресс загрузки (0.0 - 1.0)
  public let progress: Float
  
  /// Дата создания загрузки
  public let createdAt: Date
  
  /// Дата последнего обновления
  public let updatedAt: Date
  
  /// Состояние загрузки
  public let state: String
  
  public init(url: URL, metadata: Meta, resumeData: Data? = nil, progress: Float = 0.0, state: String = "pending") {
    self.url = url
    self.metadata = metadata
    self.resumeData = resumeData
    self.progress = progress
    self.createdAt = Date()
    self.updatedAt = Date()
    self.state = state
  }
  
  /// Создает обновленную копию с новыми данными
  public func updated(resumeData: Data?, progress: Float, state: String) -> PendingDownloadInfo<Meta> {
    return PendingDownloadInfo(
      url: self.url,
      metadata: self.metadata,
      resumeData: resumeData,
      progress: progress,
      state: state,
      createdAt: self.createdAt,
      updatedAt: Date()
    )
  }
  
  private init(url: URL, metadata: Meta, resumeData: Data?, progress: Float, state: String, createdAt: Date, updatedAt: Date) {
    self.url = url
    self.metadata = metadata
    self.resumeData = resumeData
    self.progress = progress
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.state = state
  }
}

extension PendingDownloadInfo: Equatable {
  public static func == (lhs: PendingDownloadInfo<Meta>, rhs: PendingDownloadInfo<Meta>) -> Bool {
    return lhs.url == rhs.url && lhs.metadata == rhs.metadata
  }
}

extension PendingDownloadInfo: Identifiable {
  public var id: URL { url }
} 