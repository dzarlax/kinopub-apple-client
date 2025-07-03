//
//  SeasonDownloadManager.swift
//  KinoPubKit
//
//  Created by Dzarlax on 02.07.2025.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import Combine
import OSLog

/// Менеджер для групповых загрузок сезонов
public class SeasonDownloadManager: ObservableObject {
  
  @Published public var seasonGroups: [SeasonDownloadGroup] = []
  @Published public var episodeInfos: [EpisodeDownloadInfo] = []
  
  private let downloadManager: DownloadManager<DownloadMeta>
  private let fileSaver: FileSaving
  private let dataFileURL: URL
  private var cancellables = Set<AnyCancellable>()
  
  // Для предотвращения частых сохранений
  private var saveTask: Task<Void, Never>?
  private let saveQueue = DispatchQueue(label: "season.download.save", qos: .utility)
  
  public init(downloadManager: DownloadManager<DownloadMeta>, fileSaver: FileSaving) {
    self.downloadManager = downloadManager
    self.fileSaver = fileSaver
    
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    self.dataFileURL = documentsPath.appendingPathComponent("SeasonDownloads.plist")
    
    setupDownloadObservation()
    
    // Асинхронная загрузка данных
    Task {
      await loadDataAsync()
    }
  }
  
  // MARK: - Public Methods
  
  /// Начинает скачивание всего сезона (асинхронно)
  @MainActor
  public func downloadSeason(
    mediaItem: MediaItem,
    season: Season,
    quality: String = "1080p"
  ) {
    Logger.kit.info("[SEASON DOWNLOAD] Starting season download for: \(mediaItem.title) Season \(season.number)")
    
    // Создаем группу загрузок для сезона
    let seasonGroup = SeasonDownloadGroup(
      mediaId: mediaItem.id,
      seasonNumber: season.number,
      seriesTitle: mediaItem.title,
      seasonTitle: season.fixedTitle,
      imageUrl: mediaItem.posters.small,
      totalEpisodes: season.episodes.count
    )
    
    // Добавляем группу если её ещё нет
    if !seasonGroups.contains(where: { $0.id == seasonGroup.id }) {
      seasonGroups.append(seasonGroup)
    }
    
    // Запускаем асинхронную загрузку эпизодов
    Task {
      await downloadEpisodesAsync(
        mediaItem: mediaItem,
        season: season,
        episodes: season.episodes,
        quality: quality,
        groupId: seasonGroup.id
      )
    }
    
    debouncedSave()
  }
  
  /// Асинхронная загрузка эпизодов с задержкой для предотвращения блокировки UI
  private func downloadEpisodesAsync(
    mediaItem: MediaItem,
    season: Season,
    episodes: [Episode],
    quality: String,
    groupId: String
  ) async {
    Logger.kit.info("[SEASON DOWNLOAD] Starting async download of \(episodes.count) episodes")
    
    // Загружаем эпизоды с небольшой задержкой между запусками
    for (index, episode) in episodes.enumerated() {
      await MainActor.run {
        downloadEpisode(
          mediaItem: mediaItem,
          season: season,
          episode: episode,
          quality: quality,
          groupId: groupId
        )
      }
      
      // Небольшая задержка между запусками (50ms) для предотвращения блокировки UI
      if index < episodes.count - 1 {
        try? await Task.sleep(nanoseconds: 50_000_000)
      }
    }
    
    Logger.kit.info("[SEASON DOWNLOAD] Completed async download setup for all episodes")
  }

  /// Начинает скачивание отдельного эпизода
  public func downloadEpisode(
    mediaItem: MediaItem,
    season: Season,
    episode: Episode,
    quality: String = "1080p",
    groupId: String? = nil
  ) {
    Logger.kit.info("[SEASON DOWNLOAD] Starting episode download: S\(season.number)E\(episode.number)")
    
    // Находим файл нужного качества
    guard let file = episode.files.first(where: { $0.quality == quality }) ?? episode.files.first else {
      Logger.kit.error("[SEASON DOWNLOAD] No suitable file found for episode \(episode.number)")
      return
    }
    
    guard let url = URL(string: file.url.http) else {
      Logger.kit.error("[SEASON DOWNLOAD] Invalid URL for episode \(episode.number)")
      return
    }
    
    // Создаем метаданные для загрузки
    let downloadableItem = DownloadableMediaItem(
      name: "S\(season.number)E\(episode.number)",
      files: episode.files,
      mediaItem: mediaItem,
      watchingMetadata: WatchingMetadata(id: episode.id, video: episode.number, season: season.number)
    )
    
    let metadata = DownloadMeta.make(from: downloadableItem)
    
    // Создаем информацию об эпизоде
    let episodeInfo = EpisodeDownloadInfo(
      groupId: groupId ?? "single_\(mediaItem.id)_\(season.number)_\(episode.number)",
      episodeNumber: episode.number,
      episodeTitle: episode.fixedTitle,
      downloadUrl: url,
      metadata: metadata
    )
    
    // Добавляем информацию об эпизоде если её ещё нет
    if !self.episodeInfos.contains(where: { $0.id == episodeInfo.id }) {
      self.episodeInfos.append(episodeInfo)
    }
    
    // Начинаем загрузку через обычный DownloadManager
    _ = downloadManager.startDownload(url: url, withMetadata: metadata)
    
    Logger.kit.info("[SEASON DOWNLOAD] Started download for episode S\(season.number)E\(episode.number)")
    debouncedSave()
  }
  
  /// Переключает раскрытие группы сезона
  @MainActor
  public func toggleGroupExpansion(groupId: String) {
    Logger.kit.info("[SEASON DOWNLOAD] Toggle expansion requested for group: \(groupId)")
    
    if let index = self.seasonGroups.firstIndex(where: { $0.id == groupId }) {
      let wasExpanded = self.seasonGroups[index].isExpanded
      self.seasonGroups[index].isExpanded.toggle()
      let isNowExpanded = self.seasonGroups[index].isExpanded
      
      Logger.kit.info("[SEASON DOWNLOAD] Group \(groupId) at index \(index): \(wasExpanded) -> \(isNowExpanded)")
      Logger.kit.info("[SEASON DOWNLOAD] Group title: \(self.seasonGroups[index].seriesTitle) - \(self.seasonGroups[index].seasonTitle)")
      
      // Логируем состояние всех групп для отладки
      for (i, group) in self.seasonGroups.enumerated() {
        Logger.kit.info("[SEASON DOWNLOAD] Group \(i): \(group.id) (\(group.seriesTitle)) - expanded: \(group.isExpanded)")
      }
      
      debouncedSave()
    } else {
      Logger.kit.error("[SEASON DOWNLOAD] Group with ID \(groupId) not found!")
      Logger.kit.info("[SEASON DOWNLOAD] Available groups:")
      for (i, group) in self.seasonGroups.enumerated() {
        Logger.kit.info("[SEASON DOWNLOAD] - \(i): \(group.id) (\(group.seriesTitle))")
      }
    }
  }
  
  /// Приостанавливает или возобновляет загрузку всех эпизодов группы
  @MainActor
  public func pauseResumeGroup(groupId: String) {
    let activeDownloads = activeDownloads(for: groupId)
    
    if activeDownloads.isEmpty {
      Logger.kit.info("[SEASON DOWNLOAD] No active downloads for group \(groupId)")
      return
    }
    
    // Определяем действие: если все загрузки приостановлены, возобновляем, иначе приостанавливаем
    let shouldResume = activeDownloads.allSatisfy { $0.state == .paused }
    
    for download in activeDownloads {
      if shouldResume && download.state == .paused {
        download.resume()
        Logger.kit.info("[SEASON DOWNLOAD] Resumed download for episode in group \(groupId)")
      } else if !shouldResume && download.state == .inProgress {
        download.pause()
        Logger.kit.info("[SEASON DOWNLOAD] Paused download for episode in group \(groupId)")
      }
    }
  }
  
  /// Переключает состояние загрузки отдельного эпизода
  @MainActor
  public func toggleEpisodeDownload(episode: EpisodeDownloadInfo) {
    // Ищем активную загрузку для этого эпизода
    if let activeDownload = downloadManager.activeDownloads[episode.downloadUrl] {
      // Есть активная загрузка - переключаем её состояние
      switch activeDownload.state {
      case .inProgress:
        activeDownload.pause()
        Logger.kit.info("[SEASON DOWNLOAD] Paused episode \(episode.episodeNumber)")
      case .paused:
        activeDownload.resume()
        Logger.kit.info("[SEASON DOWNLOAD] Resumed episode \(episode.episodeNumber)")
      default:
        Logger.kit.info("[SEASON DOWNLOAD] Cannot toggle episode in state: \(activeDownload.state.rawValue)")
      }
    } else if !episode.isDownloaded {
      // Нет активной загрузки и эпизод не загружен - начинаем загрузку
      _ = downloadManager.startDownload(url: episode.downloadUrl, withMetadata: episode.metadata)
      Logger.kit.info("[SEASON DOWNLOAD] Started download for episode \(episode.episodeNumber)")
    }
  }
  
  /// Удаляет группу загрузок сезона
  @MainActor
  public func removeSeasonGroup(groupId: String) {
    // Удаляем все эпизоды группы
    let episodesToRemove = self.episodeInfos.filter { $0.groupId == groupId }
    for episode in episodesToRemove {
      downloadManager.removeDownload(for: episode.downloadUrl)
    }
    
    // Удаляем информацию об эпизодах
    self.episodeInfos.removeAll { $0.groupId == groupId }
    
    // Удаляем группу
    seasonGroups.removeAll { $0.id == groupId }
    
    Logger.kit.info("[SEASON DOWNLOAD] Removed season group: \(groupId)")
    debouncedSave()
  }
  
  /// Получает эпизоды для конкретной группы
  public func episodes(for groupId: String) -> [EpisodeDownloadInfo] {
    return self.episodeInfos.filter { $0.groupId == groupId }.sorted { $0.episodeNumber < $1.episodeNumber }
  }
  
  /// Получает активные загрузки для группы
  public func activeDownloads(for groupId: String) -> [Download<DownloadMeta>] {
    let episodeUrls = episodes(for: groupId).map { $0.downloadUrl }
    return downloadManager.activeDownloads.values.filter { download in
      episodeUrls.contains(download.url)
    }
  }
  
  // MARK: - Private Methods
  
  private func setupDownloadObservation() {
    // Наблюдаем за изменениями в DownloadManager с throttling
    downloadManager.objectWillChange
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
      .sink { [weak self] in
        Task { @MainActor in
          await self?.updateDownloadProgressAsync()
        }
      }
      .store(in: &cancellables)
  }
  
  /// Асинхронное обновление прогресса загрузок
  @MainActor
  private func updateDownloadProgressAsync() async {
    // Выполняем тяжелые вычисления в фоновой очереди
    let progressUpdates = await withCheckedContinuation { continuation in
      Task.detached {
        var episodeUpdates: [(Int, Float, Bool)] = []
        var groupUpdates: [(Int, Int)] = []
        
        // Обновляем прогресс эпизодов
        for (index, episodeInfo) in self.episodeInfos.enumerated() {
          if let download = self.downloadManager.activeDownloads[episodeInfo.downloadUrl] {
            let newProgress = download.progress
            let isCompleted = !episodeInfo.isDownloaded && download.progress >= 1.0
            
            if episodeInfo.downloadProgress != newProgress || isCompleted {
              episodeUpdates.append((index, newProgress, isCompleted))
            }
          } else {
            // Проверяем, завершена ли загрузка
            if let downloadedFiles = self.downloadManager.getDownloadedFiles(),
               downloadedFiles.first(where: { $0.originalURL == episodeInfo.downloadUrl }) != nil {
              if !episodeInfo.isDownloaded {
                episodeUpdates.append((index, 1.0, true))
              }
            }
          }
        }
        
        // Обновляем прогресс групп сезонов
        for (index, group) in self.seasonGroups.enumerated() {
          let groupEpisodes = self.episodeInfos.filter { $0.groupId == group.id }
          let downloadedCount = groupEpisodes.filter { $0.isDownloaded }.count
          
          if group.downloadedEpisodes != downloadedCount {
            groupUpdates.append((index, downloadedCount))
          }
        }
        
        continuation.resume(returning: (episodeUpdates, groupUpdates))
      }
    }
    
    // Применяем обновления на главном потоке
    let (episodeUpdates, groupUpdates) = progressUpdates
    var hasChanges = false
    
    for (index, progress, isCompleted) in episodeUpdates {
      if index < self.episodeInfos.count {
        self.episodeInfos[index].downloadProgress = progress
        if isCompleted {
          self.episodeInfos[index].isDownloaded = true
        }
        hasChanges = true
      }
    }
    
    for (index, downloadedCount) in groupUpdates {
      if index < self.seasonGroups.count {
        self.seasonGroups[index].downloadedEpisodes = downloadedCount
        hasChanges = true
      }
    }
    
    if hasChanges {
      debouncedSave()
    }
  }
  
  /// Синхронное обновление прогресса (для совместимости)
  private func updateDownloadProgress() {
    var hasChanges = false
    
    // Обновляем прогресс эпизодов
    for index in self.episodeInfos.indices {
      let episodeInfo = self.episodeInfos[index]
      
      if let download = downloadManager.activeDownloads[episodeInfo.downloadUrl] {
        // Активная загрузка
        let newProgress = download.progress
        if self.episodeInfos[index].downloadProgress != newProgress {
          self.episodeInfos[index].downloadProgress = newProgress
          hasChanges = true
        }
        
        // Проверяем завершение через прогресс (если прогресс 1.0 и загрузка не активна)
        if !self.episodeInfos[index].isDownloaded && download.progress >= 1.0 {
          self.episodeInfos[index].isDownloaded = true
          hasChanges = true
        }
      } else {
        // Проверяем, завершена ли загрузка
        if downloadManager.getDownloadedFiles()?.first(where: { $0.originalURL == episodeInfo.downloadUrl }) != nil {
          if !self.episodeInfos[index].isDownloaded {
            self.episodeInfos[index].isDownloaded = true
            self.episodeInfos[index].downloadProgress = 1.0
            hasChanges = true
          }
        }
      }
    }
    
    // Обновляем прогресс групп сезонов
    for index in self.seasonGroups.indices {
      let group = self.seasonGroups[index]
      let groupEpisodes = episodes(for: group.id)
      let downloadedCount = groupEpisodes.filter { $0.isDownloaded }.count
      
      if self.seasonGroups[index].downloadedEpisodes != downloadedCount {
        self.seasonGroups[index].downloadedEpisodes = downloadedCount
        hasChanges = true
      }
    }
    
    if hasChanges {
      debouncedSave()
    }
  }
  
  /// Асинхронная загрузка данных в фоновой очереди
  private func loadDataAsync() async {
    await withCheckedContinuation { continuation in
      saveQueue.async {
        guard FileManager.default.fileExists(atPath: self.dataFileURL.path) else {
          Logger.kit.debug("[SEASON DOWNLOAD] No existing season downloads data found")
          continuation.resume()
          return
        }
        
        do {
          let data = try Data(contentsOf: self.dataFileURL)
          let decoder = PropertyListDecoder()
          
          let container = try decoder.decode(SeasonDownloadContainer.self, from: data)
          
          // Обновляем данные на главном потоке
          Task { @MainActor in
            self.seasonGroups = container.seasonGroups
            self.episodeInfos = container.episodeInfos
            Logger.kit.info("[SEASON DOWNLOAD] Loaded \(container.seasonGroups.count) season groups and \(container.episodeInfos.count) episodes")
          }
        } catch {
          Logger.kit.error("[SEASON DOWNLOAD] Failed to load season downloads data: \(error)")
        }
        
        continuation.resume()
      }
    }
  }
  
  /// Синхронная загрузка данных (для совместимости)
  private func loadData() {
    guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
      Logger.kit.debug("[SEASON DOWNLOAD] No existing season downloads data found")
      return
    }
    
    do {
      let data = try Data(contentsOf: dataFileURL)
      let decoder = PropertyListDecoder()
      
      let container = try decoder.decode(SeasonDownloadContainer.self, from: data)
      self.seasonGroups = container.seasonGroups
      self.episodeInfos = container.episodeInfos
      
      Logger.kit.info("[SEASON DOWNLOAD] Loaded \(self.seasonGroups.count) season groups and \(self.episodeInfos.count) episodes")
    } catch {
      Logger.kit.error("[SEASON DOWNLOAD] Failed to load season downloads data: \(error)")
    }
  }
  
  /// Асинхронное сохранение с debounce для предотвращения частых записей
  private func debouncedSave() {
    // Отменяем предыдущую задачу сохранения
    saveTask?.cancel()
    
    // Создаем новую задачу с задержкой
    saveTask = Task {
      // Ждем 500ms перед сохранением
      try? await Task.sleep(nanoseconds: 500_000_000)
      
      // Проверяем, что задача не была отменена
      guard !Task.isCancelled else { return }
      
      await saveDataAsync()
    }
  }
  
  /// Асинхронное сохранение данных в фоновой очереди
  private func saveDataAsync() async {
    let currentGroups = self.seasonGroups
    let currentEpisodes = self.episodeInfos
    
    await withCheckedContinuation { continuation in
      saveQueue.async {
        do {
          let container = SeasonDownloadContainer(seasonGroups: currentGroups, episodeInfos: currentEpisodes)
          let encoder = PropertyListEncoder()
          let data = try encoder.encode(container)
          try data.write(to: self.dataFileURL)
          
          Logger.kit.debug("[SEASON DOWNLOAD] Saved season downloads data asynchronously")
        } catch {
          Logger.kit.error("[SEASON DOWNLOAD] Failed to save season downloads data: \(error)")
        }
        
        continuation.resume()
      }
    }
  }
  
  /// Синхронное сохранение (для совместимости)
  private func saveData() {
    do {
      let container = SeasonDownloadContainer(seasonGroups: self.seasonGroups, episodeInfos: self.episodeInfos)
      let encoder = PropertyListEncoder()
      let data = try encoder.encode(container)
      try data.write(to: dataFileURL)
      
      Logger.kit.debug("[SEASON DOWNLOAD] Saved season downloads data")
    } catch {
      Logger.kit.error("[SEASON DOWNLOAD] Failed to save season downloads data: \(error)")
    }
  }
}

// MARK: - Container for Codable

private struct SeasonDownloadContainer: Codable {
  let seasonGroups: [SeasonDownloadGroup]
  let episodeInfos: [EpisodeDownloadInfo]
} 