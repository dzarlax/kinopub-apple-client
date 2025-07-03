//
//  SeasonDownloadGroup.swift
//  KinoPubKit
//
//  Created by Dzarlax on 02.07.2025.
//

import Foundation
import KinoPubBackend

/// Группа загрузок для сезона сериала
public struct SeasonDownloadGroup: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let mediaId: Int
  public let seasonNumber: Int
  public let seriesTitle: String
  public let seasonTitle: String
  public let imageUrl: String
  public let totalEpisodes: Int
  public var downloadedEpisodes: Int
  public var isExpanded: Bool
  public let createdAt: Date
  
  public init(
    mediaId: Int,
    seasonNumber: Int,
    seriesTitle: String,
    seasonTitle: String,
    imageUrl: String,
    totalEpisodes: Int,
    downloadedEpisodes: Int = 0,
    isExpanded: Bool = false
  ) {
    self.id = "season_\(mediaId)_\(seasonNumber)"
    self.mediaId = mediaId
    self.seasonNumber = seasonNumber
    self.seriesTitle = seriesTitle
    self.seasonTitle = seasonTitle
    self.imageUrl = imageUrl
    self.totalEpisodes = totalEpisodes
    self.downloadedEpisodes = downloadedEpisodes
    self.isExpanded = isExpanded
    self.createdAt = Date()
  }
  
  public var isCompleted: Bool {
    downloadedEpisodes >= totalEpisodes
  }
  
  public var progress: Float {
    guard totalEpisodes > 0 else { return 0.0 }
    return Float(downloadedEpisodes) / Float(totalEpisodes)
  }
  
  public var displayTitle: String {
    return "\(seriesTitle) - \(seasonTitle)"
  }
  
  public static func == (lhs: SeasonDownloadGroup, rhs: SeasonDownloadGroup) -> Bool {
    lhs.id == rhs.id
  }
}

/// Информация об эпизоде в группе загрузок
public struct EpisodeDownloadInfo: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let groupId: String
  public let episodeNumber: Int
  public let episodeTitle: String
  public let downloadUrl: URL
  public let metadata: DownloadMeta
  public var isDownloaded: Bool
  public var downloadProgress: Float
  public let createdAt: Date
  
  public init(
    groupId: String,
    episodeNumber: Int,
    episodeTitle: String,
    downloadUrl: URL,
    metadata: DownloadMeta,
    isDownloaded: Bool = false,
    downloadProgress: Float = 0.0
  ) {
    self.id = "\(groupId)_episode_\(episodeNumber)"
    self.groupId = groupId
    self.episodeNumber = episodeNumber
    self.episodeTitle = episodeTitle
    self.downloadUrl = downloadUrl
    self.metadata = metadata
    self.isDownloaded = isDownloaded
    self.downloadProgress = downloadProgress
    self.createdAt = Date()
  }
  
  public var displayTitle: String {
    return "Серия \(episodeNumber): \(episodeTitle)"
  }
  
  public static func == (lhs: EpisodeDownloadInfo, rhs: EpisodeDownloadInfo) -> Bool {
    lhs.id == rhs.id
  }
} 