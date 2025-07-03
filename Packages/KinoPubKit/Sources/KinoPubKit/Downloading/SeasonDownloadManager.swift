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

// MARK: - Protocol for UserActionsService to avoid circular dependencies

public protocol UserActionsServiceProtocol {
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> ToggleWatchingResponse
  func fetchWatchingInfo(id: Int, video: Int?, season: Int?) async throws -> WatchData
}

public struct ToggleWatchingResponse: Codable {
  public let status: Int
  public let watched: Int
  
  public var isWatched: Bool {
    return watched == 1
  }
  
  public init(status: Int, watched: Int) {
    self.status = status
    self.watched = watched
  }
}

public struct WatchData: Codable {
  public struct Season: Codable {
    public var id: Int
    public var number: Int
    public var status: Int
    public var episodes: [WatchDataVideoItem]
    
    public init(id: Int, number: Int, status: Int, episodes: [WatchDataVideoItem]) {
      self.id = id
      self.number = number
      self.status = status
      self.episodes = episodes
    }
  }
  
  public struct WatchDataItem: Codable {
    public var seasons: [Season]?
    public var videos: [WatchDataVideoItem]?
    
    public init(seasons: [Season]? = nil, videos: [WatchDataVideoItem]? = nil) {
      self.seasons = seasons
      self.videos = videos
    }
  }
  
  public struct WatchDataVideoItem: Codable {
    public var id: Int
    public var number: Int
    public var title: String
    public var time: TimeInterval
    public var status: Int
    
    public init(id: Int, number: Int, title: String, time: TimeInterval, status: Int) {
      self.id = id
      self.number = number
      self.title = title
      self.time = time
      self.status = status
    }
  }
  
  public var item: WatchDataItem
  
  public init(item: WatchDataItem) {
    self.item = item
  }
}

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
    
    print("🔍 [SEASON] SeasonDownloadManager initialized (grouping mode)")
    Logger.kit.info("[SEASON] SeasonDownloadManager initialized (grouping mode)")
    
    setupDownloadObservation()
  }
  
  // MARK: - Public Methods
  
  /// Группирует существующие загрузки в сезонные группы
  @MainActor
  public func groupExistingDownloads(from downloadedItems: [DownloadedFileInfo<DownloadMeta>]) {
    print("🔍 [SEASON] Grouping existing downloads...")
    Logger.kit.info("[SEASON] Grouping existing downloads...")
    
    // Очищаем текущие группы
    seasonGroups.removeAll()
    episodeInfos.removeAll()
    
    // Группируем по медиа ID и сезону
    var groupedItems: [String: [DownloadedFileInfo<DownloadMeta>]] = [:]
    
    for item in downloadedItems {
      // Проверяем, что это эпизод сериала
      guard let season = item.metadata.metadata.season, season > 0 else { continue }
      
      let groupKey = "\(item.metadata.id)_\(season)"
      if groupedItems[groupKey] == nil {
        groupedItems[groupKey] = []
      }
      groupedItems[groupKey]?.append(item)
    }
    
    // Создаем группы сезонов для каждой группы
    for (_, items) in groupedItems {
      guard items.count > 1 else { continue } // Создаем группу только если больше 1 эпизода
      
      let firstItem = items[0]
      let mediaId = firstItem.metadata.id
      guard let seasonNumber = firstItem.metadata.metadata.season else { continue }
      
      // Создаем новую группу (упрощаем - не проверяем существующие)
      let seasonGroup = SeasonDownloadGroup(
        mediaId: mediaId,
        seasonNumber: seasonNumber,
        seriesTitle: extractSeriesTitle(from: firstItem.metadata.originalTitle),
        seasonTitle: "Сезон \(seasonNumber)",
        imageUrl: firstItem.metadata.imageUrl,
        totalEpisodes: items.count,
        downloadedEpisodes: items.count // Все уже загружены
      )
      
      seasonGroups.append(seasonGroup)
      
      // Создаем информацию об эпизодах
      for item in items.sorted(by: { ($0.metadata.metadata.video ?? 0) < ($1.metadata.metadata.video ?? 0) }) {
        let episodeInfo = EpisodeDownloadInfo(
          groupId: seasonGroup.id,
          episodeNumber: item.metadata.metadata.video ?? 0,
          episodeTitle: item.metadata.localizedTitle,
          downloadUrl: item.localFileURL, // Используем локальный файл
          metadata: item.metadata,
          isDownloaded: true, // Уже загружен
          downloadProgress: 1.0
        )
        episodeInfos.append(episodeInfo)
      }
      
      print("🔍 [SEASON] Created group for \(firstItem.metadata.originalTitle) Season \(seasonNumber) with \(items.count) episodes")
      Logger.kit.info("[SEASON] Created group for \(firstItem.metadata.originalTitle) Season \(seasonNumber) with \(items.count) episodes")
    }
    
    print("🔍 [SEASON] Grouping completed. Total groups: \(self.seasonGroups.count), episodes: \(self.episodeInfos.count)")
    Logger.kit.info("[SEASON] Grouping completed. Total groups: \(self.seasonGroups.count), episodes: \(self.episodeInfos.count)")
  }
  
  /// Извлекает название сериала из полного названия эпизода
  private func extractSeriesTitle(from fullTitle: String) -> String {
    // Пытаемся удалить информацию об эпизоде (S1E1, Season 1, Episode 1, etc.)
    let patterns = [
      " S\\d+E\\d+.*$",      // " S1E1..."
      " Season \\d+.*$",     // " Season 1..."
      " Сезон \\d+.*$",      // " Сезон 1..."
      " Episode \\d+.*$",    // " Episode 1..."
      " Эпизод \\d+.*$"      // " Эпизод 1..."
    ]
    
    var cleanTitle = fullTitle
    for pattern in patterns {
      cleanTitle = cleanTitle.replacingOccurrences(
        of: pattern,
        with: "",
        options: .regularExpression
      )
    }
    
    return cleanTitle.trimmingCharacters(in: .whitespaces)
  }
  

  
  /// Начинает скачивание всего сезона (асинхронно)
  @MainActor
  public func downloadSeason(
    mediaItem: MediaItem,
    season: Season,
    quality: String = "1080p"
  ) {
    Logger.kit.info("[SEASON] Starting download: \(mediaItem.title) S\(season.number) (\(season.episodes.count) episodes)")
    
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
    
    Logger.kit.info("[SEASON] Completed setup for all episodes in season")
  }

  /// Начинает скачивание отдельного эпизода
  public func downloadEpisode(
    mediaItem: MediaItem,
    season: Season,
    episode: Episode,
    quality: String = "1080p",
    groupId: String? = nil
  ) {
    // Находим файл нужного качества
    guard let file = episode.files.first(where: { $0.quality == quality }) ?? episode.files.first else {
      Logger.kit.error("[SEASON] No file found for episode S\(season.number)E\(episode.number)")
      return
    }
    
    guard let url = URL(string: file.url.http) else {
      Logger.kit.error("[SEASON] Invalid URL for episode S\(season.number)E\(episode.number)")
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
    
    debouncedSave()
  }
  
  /// Переключает раскрытие группы сезона
  @MainActor
  public func toggleGroupExpansion(groupId: String) {
    Logger.kit.info("[SEASON] Toggle expansion for group: \(groupId)")
    if let index = self.seasonGroups.firstIndex(where: { $0.id == groupId }) {
      let oldValue = self.seasonGroups[index].isExpanded
      self.seasonGroups[index].isExpanded.toggle()
      let newValue = self.seasonGroups[index].isExpanded
      Logger.kit.info("[SEASON] Group \(groupId) expanded: \(oldValue) -> \(newValue)")
      
      // Принудительно уведомляем об изменении
      objectWillChange.send()
      
      debouncedSave()
    } else {
      Logger.kit.error("[SEASON] Group not found: \(groupId)")
    }
  }
  
  /// Приостанавливает или возобновляет загрузку всех эпизодов группы
  @MainActor
  public func pauseResumeGroup(groupId: String) {
    let activeDownloads = activeDownloads(for: groupId)
    
    if activeDownloads.isEmpty {
      return
    }
    
    // Определяем действие: если все загрузки приостановлены, возобновляем, иначе приостанавливаем
    let shouldResume = activeDownloads.allSatisfy { $0.state == .paused }
    
    for download in activeDownloads {
      if shouldResume && download.state == .paused {
        download.resume()
      } else if !shouldResume && download.state == .inProgress {
        download.pause()
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
      case .paused:
        activeDownload.resume()
      default:
        break
      }
    } else if !episode.isDownloaded {
      // Нет активной загрузки и эпизод не загружен - начинаем загрузку
      _ = downloadManager.startDownload(url: episode.downloadUrl, withMetadata: episode.metadata)
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
    
    debouncedSave()
  }
  
  /// Получает эпизоды для конкретной группы
  public func episodes(for groupId: String) -> [EpisodeDownloadInfo] {
    return self.episodeInfos
      .filter { $0.groupId == groupId }
      .sorted { $0.episodeNumber < $1.episodeNumber }
  }
  
  /// Получает активные загрузки для конкретной группы
  public func activeDownloads(for groupId: String) -> [Download<DownloadMeta>] {
    let episodeUrls = episodes(for: groupId).map { $0.downloadUrl }
    return downloadManager.activeDownloads.values.filter { episodeUrls.contains($0.url) }
  }
  
  /// Обновляет статус просмотра эпизода
  public func updateWatchStatus(episodeId: String, isWatched: Bool, progress: Float, lastTime: TimeInterval) {
    if let index = episodeInfos.firstIndex(where: { $0.id == episodeId }) {
      episodeInfos[index].isWatched = isWatched
      episodeInfos[index].watchProgress = progress
      episodeInfos[index].lastWatchTime = lastTime
      
      debouncedSave()
    }
  }
  
  /// Обновляет статусы просмотра из данных сервера
  public func updateWatchStatusFromServer(groupId: String, watchData: WatchData) {
    _ = episodes(for: groupId)
    
    // Обновляем статусы на основе данных с сервера
    if let seasons = watchData.item.seasons {
      for season in seasons {
        for serverEpisode in season.episodes {
          // Ищем соответствующий эпизод в наших данных
          if let index = episodeInfos.firstIndex(where: { episode in
            episode.groupId == groupId && episode.episodeNumber == serverEpisode.number
          }) {
            // Обновляем статус просмотра
            episodeInfos[index].isWatched = serverEpisode.status > 0
            episodeInfos[index].lastWatchTime = serverEpisode.time
            
            // Рассчитываем прогресс просмотра (приблизительно)
            if serverEpisode.time > 0 {
              // Примерная продолжительность эпизода (можно улучшить)
              let estimatedDuration: TimeInterval = 45 * 60 // 45 минут
              episodeInfos[index].watchProgress = min(Float(serverEpisode.time / estimatedDuration), 1.0)
            } else {
              episodeInfos[index].watchProgress = 0.0
            }
          }
        }
      }
    }
    
    debouncedSave()
  }
  
  /// Переключает статус просмотра эпизода через API сервера
  public func toggleEpisodeWatchStatus(
    groupId: String,
    episodeNumber: Int,
    userActionsService: Any // Используем Any для избежания циклических зависимостей
  ) async throws -> Bool {
    // Находим эпизод
    guard let episodeIndex = episodeInfos.firstIndex(where: { 
      $0.groupId == groupId && $0.episodeNumber == episodeNumber 
    }) else {
      throw NSError(domain: "SeasonDownloadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Episode not found"])
    }
    
    let episode = episodeInfos[episodeIndex]
    
    // Получаем данные о медиа из метаданных
    guard let seasonNumber = episode.metadata.metadata.season else {
      throw NSError(domain: "SeasonDownloadManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing season metadata"])
    }
    
    let mediaId = episode.metadata.metadata.id
    
    // Приводим userActionsService к нужному типу через протокол
    guard let actionsService = userActionsService as? UserActionsServiceProtocol else {
      throw NSError(domain: "SeasonDownloadManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid user actions service"])
    }
    
    // Отправляем запрос на сервер
    let response = try await actionsService.toggleWatching(
      id: mediaId,
      video: episodeNumber,
      season: seasonNumber
    )
    
    // Адаптируем ответ
    guard let adaptedResponse = adaptToggleResponse(response) else {
      throw NSError(domain: "SeasonDownloadManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to adapt response"])
    }
    
    // Обновляем локальный статус
    episodeInfos[episodeIndex].isWatched = adaptedResponse.isWatched
    if adaptedResponse.isWatched {
      episodeInfos[episodeIndex].watchProgress = 1.0
    } else {
      episodeInfos[episodeIndex].watchProgress = 0.0
      episodeInfos[episodeIndex].lastWatchTime = 0
    }
    
    debouncedSave()
    
    return adaptedResponse.isWatched
  }
  
  /// Синхронизирует статусы просмотра группы с сервером
  public func syncWatchStatusWithServer(
    groupId: String,
    userActionsService: Any
  ) async throws {
    // Получаем первый эпизод для извлечения метаданных
    guard let firstEpisode = episodes(for: groupId).first,
          let seasonNumber = firstEpisode.metadata.metadata.season else {
      throw NSError(domain: "SeasonDownloadManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing season metadata for sync"])
    }
    
    let mediaId = firstEpisode.metadata.metadata.id
    
    guard let actionsService = userActionsService as? UserActionsServiceProtocol else {
      throw NSError(domain: "SeasonDownloadManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid user actions service"])
    }
    
    // Получаем актуальные данные с сервера
    let watchDataResponse = try await actionsService.fetchWatchingInfo(
      id: mediaId,
      video: nil,
      season: seasonNumber
    )
    
    // Адаптируем данные
    guard let watchData = adaptWatchData(watchDataResponse) else {
      throw NSError(domain: "SeasonDownloadManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to adapt watch data"])
    }
    
    // Обновляем локальные данные
    updateWatchStatusFromServer(groupId: groupId, watchData: watchData)
  }
  
  // MARK: - Type Adapters
  
  /// Адаптер для преобразования ToggleWatchingResponse из протокола в локальный тип
  private func adaptToggleResponse(_ response: Any) -> ToggleWatchingResponse? {
    // Используем рефлексию для безопасного извлечения данных
    let mirror = Mirror(reflecting: response)
    
    var status: Int = 200
    var watched: Int = 0
    
    for child in mirror.children {
      if child.label == "status", let statusValue = child.value as? Int {
        status = statusValue
      } else if child.label == "watched", let watchedValue = child.value as? Int {
        watched = watchedValue
      }
    }
    
    return ToggleWatchingResponse(status: status, watched: watched)
  }
  
  /// Адаптер для преобразования WatchData из протокола в локальный тип
  private func adaptWatchData(_ data: Any) -> WatchData? {
    let mirror = Mirror(reflecting: data)
    
    for child in mirror.children {
      if child.label == "item" {
        return extractWatchDataFromItem(child.value)
      }
    }
    
    return nil
  }
  
  private func extractWatchDataFromItem(_ item: Any) -> WatchData? {
    let itemMirror = Mirror(reflecting: item)
    var seasons: [WatchData.Season] = []
    
    for child in itemMirror.children {
      if child.label == "seasons", let seasonsArray = child.value as? [Any] {
        seasons = seasonsArray.compactMap { extractSeasonFromAny($0) }
      }
    }
    
    let watchDataItem = WatchData.WatchDataItem(seasons: seasons, videos: nil)
    return WatchData(item: watchDataItem)
  }
  
  private func extractSeasonFromAny(_ season: Any) -> WatchData.Season? {
    let seasonMirror = Mirror(reflecting: season)
    var id: Int = 0
    var number: Int = 0
    var status: Int = 0
    var episodes: [WatchData.WatchDataVideoItem] = []
    
    for child in seasonMirror.children {
      switch child.label {
      case "id":
        id = child.value as? Int ?? 0
      case "number":
        number = child.value as? Int ?? 0
      case "status":
        status = child.value as? Int ?? 0
      case "episodes":
        if let episodesArray = child.value as? [Any] {
          episodes = episodesArray.compactMap { extractEpisodeFromAny($0) }
        }
      default:
        break
      }
    }
    
    return WatchData.Season(id: id, number: number, status: status, episodes: episodes)
  }
  
  private func extractEpisodeFromAny(_ episode: Any) -> WatchData.WatchDataVideoItem? {
    let episodeMirror = Mirror(reflecting: episode)
    var id: Int = 0
    var number: Int = 0
    var title: String = ""
    var time: TimeInterval = 0
    var status: Int = 0
    
    for child in episodeMirror.children {
      switch child.label {
      case "id":
        id = child.value as? Int ?? 0
      case "number":
        number = child.value as? Int ?? 0
      case "title":
        title = child.value as? String ?? ""
      case "time":
        time = child.value as? TimeInterval ?? 0
      case "status":
        status = child.value as? Int ?? 0
      default:
        break
      }
    }
    
    return WatchData.WatchDataVideoItem(id: id, number: number, title: title, time: time, status: status)
  }
  
  // MARK: - Private Methods
  
  /// Настройка наблюдения за изменениями в DownloadManager
  private func setupDownloadObservation() {
    // Наблюдаем за изменениями прогресса загрузок
    downloadManager.objectWillChange
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
      .sink { [weak self] in
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)
    
    // Наблюдаем за завершением загрузок
    NotificationCenter.default.publisher(for: .downloadCompleted)
      .sink { [weak self] notification in
        guard let url = notification.userInfo?["url"] as? URL else { return }
        self?.handleDownloadCompleted(url: url)
      }
      .store(in: &cancellables)
    
    // Наблюдаем за ошибками загрузок
    NotificationCenter.default.publisher(for: .downloadFailed)
      .sink { [weak self] notification in
        guard let url = notification.userInfo?["url"] as? URL else { return }
        self?.handleDownloadFailed(url: url)
      }
      .store(in: &cancellables)
  }
  
  /// Обрабатывает завершение загрузки
  private func handleDownloadCompleted(url: URL) {
    // Обновляем статус соответствующего эпизода
    if let index = self.episodeInfos.firstIndex(where: { $0.downloadUrl == url }) {
      self.episodeInfos[index].isDownloaded = true
      self.episodeInfos[index].downloadProgress = 1.0
      
      // Обновляем счетчик загруженных эпизодов в группе
      let groupId = self.episodeInfos[index].groupId
      if let groupIndex = self.seasonGroups.firstIndex(where: { $0.id == groupId }) {
        let downloadedCount = self.episodes(for: groupId).filter { $0.isDownloaded }.count
        self.seasonGroups[groupIndex].downloadedEpisodes = downloadedCount
      }
      
      debouncedSave()
    }
  }
  
  /// Обрабатывает ошибку загрузки
  private func handleDownloadFailed(url: URL) {
    // Сбрасываем прогресс для неудачной загрузки
    if let index = self.episodeInfos.firstIndex(where: { $0.downloadUrl == url }) {
      self.episodeInfos[index].downloadProgress = 0.0
      debouncedSave()
    }
  }
  
  /// Обновляет прогресс загрузки эпизодов
  private func updateDownloadProgress() {
    for (index, episode) in self.episodeInfos.enumerated() {
      if let activeDownload = downloadManager.activeDownloads[episode.downloadUrl] {
        self.episodeInfos[index].downloadProgress = activeDownload.progress
      }
    }
  }
  
  /// Асинхронная загрузка данных
  private func loadDataAsync() async {
    await withCheckedContinuation { continuation in
      saveQueue.async {
        guard FileManager.default.fileExists(atPath: self.dataFileURL.path) else {
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
          }
        } catch {
          Logger.kit.error("[SEASON] Failed to load data: \(error)")
        }
        
        continuation.resume()
      }
    }
  }
  
  /// Синхронная загрузка данных (для совместимости)
  private func loadData() {
    print("🔍 [SEASON] Attempting to load data from: \(self.dataFileURL.path)")
    Logger.kit.info("[SEASON] Attempting to load data from: \(self.dataFileURL.path)")
    
    guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
      print("🔍 [SEASON] Data file does not exist, starting with empty data")
      Logger.kit.info("[SEASON] Data file does not exist, starting with empty data")
      return
    }
    
    do {
      let data = try Data(contentsOf: dataFileURL)
      print("🔍 [SEASON] Read \(data.count) bytes from data file")
      Logger.kit.info("[SEASON] Read \(data.count) bytes from data file")
      
      let decoder = PropertyListDecoder()
      let container = try decoder.decode(SeasonDownloadContainer.self, from: data)
      
      self.seasonGroups = container.seasonGroups
      self.episodeInfos = container.episodeInfos
      
      print("🔍 [SEASON] Successfully loaded \(self.seasonGroups.count) season groups and \(self.episodeInfos.count) episodes")
      Logger.kit.info("[SEASON] Successfully loaded \(self.seasonGroups.count) season groups and \(self.episodeInfos.count) episodes")
      
    } catch {
      print("🔍 [SEASON] Failed to load data: \(error)")
      Logger.kit.error("[SEASON] Failed to load data: \(error)")
    }
  }
  
  /// Отложенное сохранение данных для предотвращения частых операций I/O
  private func debouncedSave() {
    // Отменяем предыдущую задачу сохранения
    saveTask?.cancel()
    
    // Создаем новую задачу с задержкой
    saveTask = Task {
      try? await Task.sleep(nanoseconds: 500_000_000) // 500ms задержка
      
      guard !Task.isCancelled else { return }
      
      await saveDataAsync()
    }
  }
  
  /// Асинхронное сохранение данных
  private func saveDataAsync() async {
    await withCheckedContinuation { continuation in
      saveQueue.async {
        do {
          let container = SeasonDownloadContainer(seasonGroups: self.seasonGroups, episodeInfos: self.episodeInfos)
          let encoder = PropertyListEncoder()
          let data = try encoder.encode(container)
          try data.write(to: self.dataFileURL)
          
        } catch {
          Logger.kit.error("[SEASON] Failed to save data: \(error)")
        }
        
        continuation.resume()
      }
    }
  }
  
  /// Синхронное сохранение данных
  private func saveData() {
    do {
      let container = SeasonDownloadContainer(seasonGroups: self.seasonGroups, episodeInfos: self.episodeInfos)
      let encoder = PropertyListEncoder()
      let data = try encoder.encode(container)
      try data.write(to: dataFileURL)
      
    } catch {
      Logger.kit.error("[SEASON] Failed to save data: \(error)")
    }
  }
}

// MARK: - Container for Codable

private struct SeasonDownloadContainer: Codable {
  let seasonGroups: [SeasonDownloadGroup]
  let episodeInfos: [EpisodeDownloadInfo]
} 