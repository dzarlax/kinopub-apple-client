//
//  DownloadsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit

struct DownloadsView: View {
  
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var appContext: AppContext
  @StateObject private var catalog: DownloadsCatalog
  
  init(catalog: @autoclosure @escaping () -> DownloadsCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.downloadsRoutes) {
      ZStack {
        if catalog.isEmpty {
          emptyView
        } else {
          downloadsList
        }
      }
      .navigationTitle("Downloads")
      .background(Color.KinoPub.background)
      .navigationDestination(for: DownloadsRoutes.self) { route in
        switch route {
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        }
      }
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    
  }
  
  var downloadsList: some View {
    List {
      seasonGroupsList
      activeDownloadsList
      downloadedFilesList
    }
    .listStyle(.inset)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }
  
  var seasonGroupsList: some View {
    ForEach(catalog.seasonGroups, id: \.id) { seasonGroup in
      let groupId = seasonGroup.id // Захватываем ID в локальную переменную
      SeasonDownloadGroupView(
        seasonGroup: seasonGroup,
        episodes: catalog.episodes(for: groupId),
        activeDownloads: catalog.activeDownloads(for: groupId),
        onToggleExpansion: {
          print("🔄 Toggle expansion for group: \(groupId)")
          catalog.toggleSeasonGroupExpansion(groupId: groupId)
        },
        onRemoveGroup: {
          print("🗑️ Remove group: \(groupId)")
          catalog.removeSeasonGroup(groupId: groupId)
        },
        onPauseResumeGroup: {
          print("⏯️ Pause/Resume group: \(groupId)")
          catalog.pauseResumeSeasonGroup(groupId: groupId)
        },
        onToggleEpisode: { episode in
          catalog.toggleEpisodeDownload(episode: episode)
        },
        onPlayEpisode: { episode in
          navigationState.downloadsRoutes.append(.player(episode.metadata))
        }
      )
      .id(seasonGroup.id) // Явно устанавливаем ID для SwiftUI
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden, edges: .all)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  var activeDownloadsList: some View {
    ForEach(catalog.activeDownloads, id: \.url) { download in
      // Фильтруем загрузки, которые не входят в сезоны
      if !isPartOfSeasonGroup(download: download) {
        NavigationLink(value: DownloadsRoutes.player(download.metadata)) {
          DownloadedItemView(mediaItem: download.metadata, progress: download.progress) { paused in
            catalog.toggle(download: download)
          }
        }
      }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteActiveDownload(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  var downloadedFilesList: some View {
    ForEach(catalog.downloadedItems, id: \.originalURL) { fileInfo in
      // Фильтруем загруженные файлы, которые не входят в группы сезонов
      if !isPartOfSeasonGroup(fileInfo: fileInfo) {
        NavigationLink(value: DownloadsRoutes.player(fileInfo.metadata)) {
          DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil) { paused in
            
          }
        }
      }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  var emptyView: some View {
    VStack {
      Text("You don't have any downloads yet")
        .font(Font.KinoPub.subheader)
        .foregroundStyle(Color.KinoPub.text)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background)
  }
  
  // MARK: - Helper Methods
  
  private func isPartOfSeasonGroup(download: Download<DownloadMeta>) -> Bool {
    // Проверяем, является ли загрузка частью какой-либо группы сезона
    for seasonGroup in catalog.seasonGroups {
      let episodes = catalog.episodes(for: seasonGroup.id)
      if episodes.contains(where: { $0.downloadUrl == download.url }) {
        return true
      }
    }
    return false
  }
  
  private func isPartOfSeasonGroup(fileInfo: DownloadedFileInfo<DownloadMeta>) -> Bool {
    // Проверяем, является ли загруженный файл частью какой-либо группы сезона
    for seasonGroup in catalog.seasonGroups {
      let episodes = catalog.episodes(for: seasonGroup.id)
      if episodes.contains(where: { $0.downloadUrl == fileInfo.originalURL }) {
        return true
      }
    }
    return false
  }
}

struct DownloadsView_Previews: PreviewProvider {
  static var previews: some View {
    
    let database = DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())
    
    let downloadManager = DownloadManager<DownloadMeta>(fileSaver: FileSaver(), database: database)
    
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: database,
                                            downloadManager: downloadManager,
                                            seasonDownloadManager: SeasonDownloadManager(downloadManager: downloadManager, fileSaver: FileSaver())))
  }
}
