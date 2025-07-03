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
    self.downloadsDatabase = downloadsDatabase
    self.downloadManager = downloadManager
    self.seasonDownloadManager = seasonDownloadManager
  }
  
  func refresh() {
    self.downloadedItems = downloadsDatabase.readData() ?? []
    self.activeDownloads = downloadManager.activeDownloads.map({ $0.value })
    self.seasonGroups = seasonDownloadManager.seasonGroups
    
    cancellables.removeAll()
    self.activeDownloads.forEach({
      let c = $0.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
      self.cancellables.append(c)
    })
    
    // Подписываемся на изменения в SeasonDownloadManager
    let seasonCancellable = seasonDownloadManager.objectWillChange.sink(receiveValue: { [weak self] in
      self?.seasonGroups = self?.seasonDownloadManager.seasonGroups ?? []
      self?.objectWillChange.send()
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
  
  func toggleSeasonGroupExpansion(groupId: String) {
    seasonDownloadManager.toggleGroupExpansion(groupId: groupId)
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
}
