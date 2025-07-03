//
//  DownloadedItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI
import KinoPubKit

public struct DownloadedItemView: View {
  
  private var mediaItem: DownloadMeta
  private var progress: Float?
  private var onDownloadStateChange: (Bool) -> Void
  
  @State private var isWatched: Bool = false
  @State private var watchProgress: Float = 0.0
  
  public init(mediaItem: DownloadMeta,
              progress: Float?,
              onDownloadStateChange: @escaping (Bool) -> Void) {
    self.mediaItem = mediaItem
    self.progress = progress
    self.onDownloadStateChange = onDownloadStateChange
  }
  
  public var body: some View {
    HStack(alignment: .center) {
      // Индикатор просмотра слева
      watchStatusIndicator
      
      image
        
      VStack(alignment: .leading) {
        title
        subtitle
      }.padding(.all, 5)
      
      if let progress = progress {
        Spacer()
        if progress != 1.0 {
          ProgressButton(progress: progress) { state in
            onDownloadStateChange(state == .pause)
          }
          .padding(.trailing, 16)
        }
      } else {
        Spacer()
      }
    }
    .padding(.vertical, 8)
    .task {
      await loadWatchStatus()
    }
  }
  
  var image: some View {
    AsyncImage(url: URL(string: mediaItem.imageUrl)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .small, orientation: .vertical)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.small.width,
               height: PosterStyle.Size.small.height)
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text(mediaItem.localizedTitle)
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
      .padding(.bottom, 10)
  }
  
  var subtitle: some View {
    Text(mediaItem.originalTitle)
      .lineLimit(1)
      .font(.system(size: 12.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }
  
  var watchStatusIndicator: some View {
    VStack {
      if isWatched {
        // Полностью просмотрен - зеленый кружок
        Circle()
          .fill(Color.green)
          .frame(width: 12, height: 12)
      } else if watchProgress > 0.1 {
        // Частично просмотрен - оранжевый кружок
        Circle()
          .fill(Color.orange)
          .frame(width: 12, height: 12)
      } else {
        // Не просмотрен - серый кружок
        Circle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 12, height: 12)
      }
    }
    .frame(width: 20)
  }
  
  @MainActor
  private func loadWatchStatus() async {
    // Получаем реальный статус просмотра из API
    let actionsService = AppContext.shared.actionsService
    
    do {
      let watchData = try await actionsService.fetchWatchingInfo(
        id: mediaItem.metadata.id,
        video: mediaItem.metadata.video,
        season: mediaItem.metadata.season
      )
      
      // Ищем соответствующий эпизод в данных
      if let season = mediaItem.metadata.season,
         let video = mediaItem.metadata.video,
         let seasonData = watchData.item.seasons?.first(where: { $0.number == season }),
         let episodeData = seasonData.episodes.first(where: { $0.number == video }) {
        
        // Обновляем статус на основе данных сервера
        // status: 1 = просмотрен, 0 = не просмотрен, -1 = не просмотрен
        isWatched = episodeData.status == 1
        
        // Если есть время просмотра, вычисляем прогресс
        if episodeData.time > 0 && !isWatched {
          // Примерная длительность эпизода из API (в секундах)
          // Если нет данных о длительности, считаем что прогресс есть
          watchProgress = Float(min(episodeData.time / 1500.0, 0.95)) // 25 минут = 1500 сек
        } else if isWatched {
          watchProgress = 1.0
        } else {
          watchProgress = 0.0
        }
        
        print("✅ Watch status loaded for item \(mediaItem.metadata.id): watched=\(isWatched), progress=\(watchProgress)")
        
      } else if mediaItem.metadata.season == nil && mediaItem.metadata.video == nil {
        // Это фильм, а не сериал
        if let videoData = watchData.item.videos?.first {
          isWatched = videoData.status == 1
          if videoData.time > 0 && !isWatched {
            watchProgress = Float(min(videoData.time / 5400.0, 0.95)) // 90 минут = 5400 сек для фильма
          } else if isWatched {
            watchProgress = 1.0
          } else {
            watchProgress = 0.0
          }
        }
        print("✅ Watch status loaded for movie \(mediaItem.metadata.id): watched=\(isWatched), progress=\(watchProgress)")
      } else {
        print("⚠️ Could not find episode data for item \(mediaItem.metadata.id), season=\(mediaItem.metadata.season ?? 0), video=\(mediaItem.metadata.video ?? 0)")
      }
      
    } catch {
      print("❌ Failed to load watch status for item \(mediaItem.metadata.id): \(error)")
      // В случае ошибки оставляем значения по умолчанию
      isWatched = false
      watchProgress = 0.0
    }
  }
  
}

#Preview {
  DownloadedItemView(
    mediaItem: DownloadMeta(
      id: 1,
      files: [],
      originalTitle: "Original Test",
      localizedTitle: "Test Movie",
      imageUrl: "",
      metadata: WatchingMetadata(id: 1, video: nil, season: nil)
    ), 
    progress: 0.5
  ) { _ in
    
  }
}

