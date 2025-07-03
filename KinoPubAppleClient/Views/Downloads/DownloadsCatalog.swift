//
//  DownloadsCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import KinoPubKit
import OSLog
import Combine

@MainActor
class DownloadsCatalog: ObservableObject {
  
  private var downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var downloadManager: DownloadManager<DownloadMeta>
  private var seasonDownloadManager: SeasonDownloadManager
  
  @Published public var downloadedItems: [DownloadedFileInfo<DownloadMeta>] = []
  @Published public var activeDownloads: [Download<DownloadMeta>] = []
  @Published public var seasonGroups: [SeasonDownloadGroup] = []
  
  var cancellables = [AnyCancellable]()
  
  var isEmpty: Bool {
    downloadedItems.isEmpty && activeDownloads.isEmpty && seasonGroups.isEmpty
  }
  
  init(downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>, downloadManager: DownloadManager<DownloadMeta>, seasonDownloadManager: SeasonDownloadManager) {
    print("🔍 [CATALOG] Initializing DownloadsCatalog with SeasonDownloadManager...")
    self.downloadsDatabase = downloadsDatabase
    self.downloadManager = downloadManager
    self.seasonDownloadManager = seasonDownloadManager
    print("🔍 [CATALOG] DownloadsCatalog initialized, seasonDownloadManager.seasonGroups.count = \(seasonDownloadManager.seasonGroups.count)")
  }
  
  func refresh() {
    print("[CATALOG] Starting refresh...")
    Logger.app.info("[CATALOG] Starting refresh...")
    
    // Загружаем все данные
    let allDownloadedItems = downloadManager.getDownloadedFiles() ?? []
    let allActiveDownloads = downloadManager.activeDownloads.map({ $0.value })
    let allSeasonGroups = seasonDownloadManager.seasonGroups
    
    // Получаем ID всех эпизодов, которые уже сгруппированы в сезоны
    let groupedEpisodeIds = Set(seasonDownloadManager.episodeInfos.map { $0.metadata.id })
    
    // Исключаем сгруппированные эпизоды из общего списка
    let filteredDownloadedItems = allDownloadedItems.filter { item in
      !groupedEpisodeIds.contains(item.metadata.id)
    }
    
    // Обновляем состояние
    downloadedItems = filteredDownloadedItems
    activeDownloads = allActiveDownloads
    seasonGroups = allSeasonGroups
    
    // Автоматически группируем сериалы при каждом обновлении
    if allSeasonGroups.isEmpty && !allDownloadedItems.isEmpty {
      print("[CATALOG] Auto-grouping series...")
      Logger.app.info("[CATALOG] Auto-grouping series...")
      seasonDownloadManager.groupExistingDownloads(from: allDownloadedItems)
      
      // Обновляем данные после группировки
      let updatedSeasonGroups = seasonDownloadManager.seasonGroups
      let updatedGroupedEpisodeIds = Set(seasonDownloadManager.episodeInfos.map { $0.metadata.id })
      let updatedFilteredDownloadedItems = allDownloadedItems.filter { item in
        !updatedGroupedEpisodeIds.contains(item.metadata.id)
      }
      
      downloadedItems = updatedFilteredDownloadedItems
      seasonGroups = updatedSeasonGroups
      
      print("[CATALOG] Auto-grouping completed: \(updatedFilteredDownloadedItems.count) downloaded items, \(updatedSeasonGroups.count) season groups")
      Logger.app.info("[CATALOG] Auto-grouping completed: \(updatedFilteredDownloadedItems.count) downloaded items, \(updatedSeasonGroups.count) season groups")
    } else {
      print("[CATALOG] Loaded: \(filteredDownloadedItems.count) downloaded items, \(allActiveDownloads.count) active downloads, \(allSeasonGroups.count) season groups")
      Logger.app.info("[CATALOG] Loaded: \(filteredDownloadedItems.count) downloaded items, \(allActiveDownloads.count) active downloads, \(allSeasonGroups.count) season groups")
    }
    
    print("[CATALOG] Refresh completed")
    Logger.app.info("[CATALOG] Refresh completed")
    
    // Подписываемся на изменения активных загрузок
    cancellables.removeAll()
    self.activeDownloads.forEach({
      let c = $0.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
      self.cancellables.append(c)
    })
    
    // Подписываемся на изменения в SeasonDownloadManager
    let seasonCancellable = seasonDownloadManager.objectWillChange.sink(receiveValue: { [weak self] in
      guard let self = self else { return }
      let oldCount = self.seasonGroups.count
      self.seasonGroups = self.seasonDownloadManager.seasonGroups
      Logger.app.info("[CATALOG] Season groups updated: \(oldCount) -> \(self.seasonGroups.count)")
      self.objectWillChange.send()
    })
    self.cancellables.append(seasonCancellable)
  }
  
  func deleteDownloadedItem(at indexSet: IndexSet) {
    for index in indexSet {
      let item = downloadedItems[index]
      downloadsDatabase.remove(fileInfo: item)
    }
  }
  
  func deleteActiveDownload(at indexSet: IndexSet) {
    for index in indexSet {
      let item = activeDownloads[index]
      downloadManager.removeDownload(for: item.url)
    }
  }
  
  func toggle(download: Download<DownloadMeta>) {
    if download.state == .inProgress {
      download.pause()
    } else {
      download.resume()
    }
  }
  
  // MARK: - Season Downloads
  
  func createTestSeason() {
    print("🔍 [CATALOG] Creating test season...")
    Logger.app.info("[CATALOG] Creating test season...")
    seasonDownloadManager.createTestSeason()
    refresh()
  }
  
  func groupExistingDownloads() {
    print("🔍 [CATALOG] Grouping existing downloads...")
    Logger.app.info("[CATALOG] Grouping existing downloads...")
    seasonDownloadManager.groupExistingDownloads(from: downloadedItems)
    refresh()
  }
  
  func toggleSeasonGroupExpansion(groupId: String) {
    Logger.app.info("[CATALOG] Toggle expansion for group: \(groupId)")
    seasonDownloadManager.toggleGroupExpansion(groupId: groupId)
    Logger.app.info("[CATALOG] After toggle, season groups count: \(self.seasonGroups.count)")
  }
  
  func pauseResumeSeasonGroup(groupId: String) {
    seasonDownloadManager.pauseResumeGroup(groupId: groupId)
  }
  
  func removeSeasonGroup(groupId: String) {
    seasonDownloadManager.removeSeasonGroup(groupId: groupId)
  }
  
  func episodes(for groupId: String) -> [EpisodeDownloadInfo] {
    return seasonDownloadManager.episodes(for: groupId)
  }
  
  func activeDownloads(for groupId: String) -> [Download<DownloadMeta>] {
    return seasonDownloadManager.activeDownloads(for: groupId)
  }
  
  func toggleEpisodeDownload(episode: EpisodeDownloadInfo) {
    seasonDownloadManager.toggleEpisodeDownload(episode: episode)
  }
  
  /// Обновляет статус просмотра эпизода
  func updateEpisodeWatchStatus(episodeId: String, isWatched: Bool, progress: Float = 0.0, lastTime: TimeInterval = 0.0) {
    seasonDownloadManager.updateWatchStatus(episodeId: episodeId, isWatched: isWatched, progress: progress, lastTime: lastTime)
  }
  
  /// Обновляет статусы просмотра для группы сезонов
  func refreshWatchStatusForGroup(groupId: String, userActionsService: UserActionsService) async {
    do {
      // groupId имеет формат "season_mediaId_seasonNumber"
      let components = groupId.components(separatedBy: "_")
      guard components.count >= 3,
            let mediaId = Int(components[1]),
            let seasonNumber = Int(components[2]) else {
        print("Invalid groupId format: \(groupId)")
        return
      }
      
      let serverWatchData = try await userActionsService.fetchWatchingInfo(
        id: mediaId,
        video: nil,
        season: seasonNumber
      )
      
      // TODO: Обработать полученные данные о статусе просмотра
      print("Received watch data for group \(groupId): \(serverWatchData)")
      
    } catch {
      print("Failed to refresh watch status for group \(groupId): \(error)")
    }
  }
  
  /// Обновляет статусы просмотра для всех групп сезонов
  func refreshAllWatchStatuses(userActionsService: UserActionsService) async {
    for group in seasonGroups {
      await refreshWatchStatusForGroup(groupId: group.id, userActionsService: userActionsService)
      
      // Небольшая задержка между запросами чтобы не перегружать сервер
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
  }
  
  /// Переключает статус просмотра эпизода через API сервера
  func toggleEpisodeWatchStatus(episode: EpisodeDownloadInfo, userActionsService: UserActionsService) async {
    do {
      let newWatchStatus = try await seasonDownloadManager.toggleEpisodeWatchStatus(
        groupId: episode.groupId,
        episodeNumber: episode.episodeNumber,
        userActionsService: userActionsService
      )
      
      Logger.app.info("Episode \(episode.episodeNumber) watch status toggled to: \(newWatchStatus)")
      
    } catch {
      Logger.app.error("Failed to toggle episode watch status: \(error)")
    }
  }
}
