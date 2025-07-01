//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit

// MARK: - Loading State
enum LoadingState<T> {
  case idle
  case loading
  case loaded(T)
  case failed(AppError)
  
  var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }
  
  var value: T? {
    if case .loaded(let value) = self { return value }
    return nil
  }
  
  var error: AppError? {
    if case .failed(let error) = self { return error }
    return nil
  }
}

// MARK: - MediaItemModel
@MainActor
class MediaItemModel: ObservableObject {

  // MARK: - Dependencies
  private let itemsService: VideoContentService
  private let downloadManager: DownloadManager<DownloadMeta>
  private let errorHandler: ErrorHandler
  private let mediaItemId: Int
  
  // MARK: - Public Properties
  let linkProvider: NavigationLinkProvider
  
  // MARK: - Published Properties
  @Published private(set) var loadingState: LoadingState<MediaItem> = .idle
  @Published private(set) var downloadProgress: [String: Float] = [:]

  // MARK: - Computed Properties
  var mediaItem: MediaItem? {
    loadingState.value
  }
  
  var isLoading: Bool {
    loadingState.isLoading
  }

  // MARK: - Init
  init(mediaItemId: Int,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
  }

  // MARK: - Public Methods
  func fetchData() async {
    guard loadingState.isLoading == false else { return }
    
    loadingState = .loading
    
    do {
      let response = try await itemsService.fetchDetails(for: "\(mediaItemId)")
      var item = response.item
      
      // Process seasons data
      if let seasons = item.seasons {
        item.seasons = seasons.map { season in
          var modifiedSeason = season
          modifiedSeason.mediaId = item.id
          return modifiedSeason
        }
      }
      
      loadingState = .loaded(item)
      Logger.app.info("Successfully loaded media item: \(self.mediaItemId)")
      
    } catch {
      let appError = AppError.networkError(error)
      loadingState = .failed(appError)
      errorHandler.setError(appError)
      Logger.app.error("Failed to load media item \(self.mediaItemId): \(error)")
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    guard let url = URL(string: file.url.http) else {
      errorHandler.handleDownloadError("Invalid URL")
      return
    }
    
    let metadata = DownloadMeta.make(from: item)
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    
    // Monitor download progress
    observeDownloadProgress(for: download, fileId: "\(file.id)")
    
    Logger.app.info("Started download for item: \(item.id)")
  }
  
  func retry() async {
    await fetchData()
  }
  
  // MARK: - Private Methods
  private func observeDownloadProgress(for download: Download<DownloadMeta>, fileId: String) {
    // This would typically use Combine to observe download progress
    // For now, we'll update progress manually
    downloadProgress[fileId] = 0.0
  }
}

// MARK: - Preview Support
extension MediaItemModel {
  static func mock() -> MediaItemModel {
    MediaItemModel(
      mediaItemId: 1,
      itemsService: VideoContentServiceMock(),
      downloadManager: DownloadManager<DownloadMeta>(fileSaver: FileSaver(), database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())),
      linkProvider: MainRoutesLinkProvider(),
      errorHandler: ErrorHandler()
    )
  }
}
