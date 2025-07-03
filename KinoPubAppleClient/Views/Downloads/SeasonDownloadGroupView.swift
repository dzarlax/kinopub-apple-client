//
//  SeasonDownloadGroupView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.07.2025.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubUI

struct SeasonDownloadGroupView: View {
  let seasonGroup: SeasonDownloadGroup
  let episodes: [EpisodeDownloadInfo]
  let activeDownloads: [Download<DownloadMeta>]
  let onToggleExpansion: () -> Void
  let onRemoveGroup: () -> Void
  let onPauseResumeGroup: () -> Void
  let onToggleEpisode: (EpisodeDownloadInfo) -> Void
  let onPlayEpisode: (EpisodeDownloadInfo) -> Void
  let onToggleWatchStatus: (EpisodeDownloadInfo) -> Void
  
  // Добавляем локальное состояние для отслеживания раскрытия
  @State private var localIsExpanded: Bool = false
  
  private var hasActiveDownloads: Bool {
    !activeDownloads.isEmpty
  }
  
  private var isGroupPaused: Bool {
    activeDownloads.allSatisfy { $0.state == .paused }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Заголовок группы
      groupHeader
      
      // Список эпизодов (если раскрыто)
      if localIsExpanded {
        episodesList
      }
    }
    .background(Color.KinoPub.background)
    .cornerRadius(12)
    .onAppear {
      localIsExpanded = seasonGroup.isExpanded
    }
    .onChange(of: seasonGroup.isExpanded) { newValue in
      print("📱 [UI] seasonGroup.isExpanded changed for \(seasonGroup.id): \(localIsExpanded) -> \(newValue)")
      DispatchQueue.main.async {
        localIsExpanded = newValue
        print("📱 [UI] localIsExpanded updated for \(seasonGroup.id): \(localIsExpanded)")
      }
    }
  }
  
  private var groupHeader: some View {
    HStack(spacing: 12) {
      // Иконка сериала
      AsyncImage(url: URL(string: seasonGroup.imageUrl)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Image(systemName: "tv")
          .font(.title2)
          .foregroundColor(.secondary)
      }
      .frame(width: 60, height: 90)
      .clipped()
      .cornerRadius(8)
      
      // Информация о сезоне (кликабельная область для раскрытия)
      VStack(alignment: .leading, spacing: 4) {
        Text(seasonGroup.seriesTitle)
          .font(.headline)
          .foregroundColor(.primary)
          .lineLimit(1)
        
        Text(seasonGroup.seasonTitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)
        
        // Прогресс загрузки
        HStack(spacing: 8) {
          ProgressView(value: seasonGroup.progress)
            .progressViewStyle(LinearProgressViewStyle())
          
          Text("\(seasonGroup.downloadedEpisodes)/\(seasonGroup.totalEpisodes)")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(minWidth: 40)
        }
        
        // Статус загрузки
        if hasActiveDownloads {
          Text(isGroupPaused ? "Приостановлено" : "Загружается...")
            .font(.caption)
            .foregroundColor(isGroupPaused ? .orange : .blue)
        } else if seasonGroup.isCompleted {
          Text("Завершено")
            .font(.caption)
            .foregroundColor(.green)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        print("🔄 Info area toggle for group: \(seasonGroup.id), current state: \(localIsExpanded)")
        onToggleExpansion()
      }
      
      Spacer()
      
      // Кнопка раскрытия (отдельно от других кнопок)
      Button(action: {
        print("🔄 Button toggle for group: \(seasonGroup.id), current state: \(localIsExpanded)")
        onToggleExpansion()
      }) {
        Image(systemName: localIsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
          .font(.title)
          .foregroundColor(.blue)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Кнопки управления (отдельно от раскрывашки)
      controlButtons
    }
    .padding()
    .background(Color.KinoPub.selectionBackground)
  }
  
  private var controlButtons: some View {
    HStack(spacing: 16) {
      // Кнопка паузы/возобновления
      if hasActiveDownloads {
        Button(action: onPauseResumeGroup) {
          Image(systemName: isGroupPaused ? "play.circle.fill" : "pause.circle.fill")
            .font(.title)
            .foregroundColor(isGroupPaused ? .green : .orange)
        }
        .buttonStyle(PlainButtonStyle())
      }
      
      // Кнопка удаления (отдельно и с большим отступом)
      Button(action: onRemoveGroup) {
        Image(systemName: "trash.circle.fill")
          .font(.title)
          .foregroundColor(.red)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }
  
  private var episodesList: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal)
      
      LazyVStack(spacing: 4) {
        ForEach(episodes, id: \.id) { episode in
          EpisodeRowView(
            episode: episode,
            activeDownload: activeDownloads.first { $0.url == episode.downloadUrl },
            onToggle: { onToggleEpisode(episode) },
            onPlay: { onPlayEpisode(episode) },
            onToggleWatchStatus: { onToggleWatchStatus(episode) }
          )
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 8)
    }
  }
}

// MARK: - Episode Row View

private struct EpisodeRowView: View {
  let episode: EpisodeDownloadInfo
  let activeDownload: Download<DownloadMeta>?
  let onToggle: () -> Void
  let onPlay: () -> Void
  let onToggleWatchStatus: () -> Void
  
  private var isDownloading: Bool {
    activeDownload?.state == .inProgress
  }
  
  private var isPaused: Bool {
    activeDownload?.state == .paused
  }
  
  private var progress: Float {
    activeDownload?.progress ?? (episode.isDownloaded ? 1.0 : 0.0)
  }
  
  private var watchStatusColor: Color {
    if episode.isWatched {
      return .green
    } else if episode.watchProgress > 0.1 {
      return .orange
    } else {
      return .secondary
    }
  }
  
  var body: some View {
    HStack(spacing: 12) {
      // Индикатор статуса просмотра (большой кружок слева) - кликабельный
      Button(action: onToggleWatchStatus) {
        Circle()
          .fill(watchStatusColor)
          .frame(width: 12, height: 12)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Номер эпизода
      Text("\(episode.episodeNumber)")
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
        .frame(width: 24, alignment: .center)
      
      // Название эпизода 
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(episode.episodeTitle)
            .font(.subheadline)
            .foregroundColor(.primary)
            .lineLimit(1)
          
          // Статус просмотра в тексте
          if episode.isWatched {
            Image(systemName: "eye.fill")
              .font(.caption)
              .foregroundColor(.green)
          } else if episode.watchProgress > 0.1 {
            Image(systemName: "eye")
              .font(.caption)
              .foregroundColor(.orange)
          }
        }
        
        // Прогресс бар для активных загрузок
        if let activeDownload = activeDownload {
          ProgressView(value: activeDownload.progress)
            .progressViewStyle(LinearProgressViewStyle())
            .scaleEffect(y: 0.5)
        } else if episode.watchProgress > 0.1 && !episode.isWatched {
          // Прогресс просмотра для частично просмотренных эпизодов
          ProgressView(value: episode.watchProgress)
            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            .scaleEffect(y: 0.5)
        }
      }
      
      Spacer()
      
      // Статус и кнопки управления
      HStack(spacing: 12) {
        // Статус загрузки
        if episode.isDownloaded {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .foregroundColor(.green)
        } else if isDownloading {
          ProgressView()
            .scaleEffect(0.8)
        } else if isPaused {
          Image(systemName: "pause.circle.fill")
            .font(.title3)
            .foregroundColor(.orange)
        }
        
        // Кнопка воспроизведения (если загружено)
        if episode.isDownloaded {
          Button(action: onPlay) {
            Image(systemName: "play.circle.fill")
              .font(.title2)
              .foregroundColor(.blue)
          }
          .buttonStyle(PlainButtonStyle())
        }
        
        // Кнопка управления загрузкой
        if let activeDownload = activeDownload {
          Button(action: onToggle) {
            Image(systemName: activeDownload.state == .paused ? "play.circle" : "pause.circle")
              .font(.title3)
              .foregroundColor(.orange)
          }
          .buttonStyle(PlainButtonStyle())
        } else if !episode.isDownloaded {
          Button(action: onToggle) {
            Image(systemName: "arrow.down.circle")
              .font(.title3)
              .foregroundColor(.blue)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .background(Color.KinoPub.background.opacity(0.5))
    .cornerRadius(8)
  }
}

// MARK: - Preview

#Preview {
  let mockSeasonGroup = SeasonDownloadGroup(
    mediaId: 1,
    seasonNumber: 1,
    seriesTitle: "Тестовый сериал",
    seasonTitle: "Сезон 1",
    imageUrl: "https://example.com/poster.jpg",
    totalEpisodes: 10,
    downloadedEpisodes: 3,
    isExpanded: true
  )
  
  let mockEpisodes = [
    EpisodeDownloadInfo(
      groupId: "test",
      episodeNumber: 1,
      episodeTitle: "Пилотная серия",
      downloadUrl: URL(string: "https://example.com/ep1.mp4")!,
      metadata: DownloadMeta(
        id: 1,
        files: [],
        originalTitle: "Test Episode 1",
        localizedTitle: "Тестовый эпизод 1",
        imageUrl: "",
        metadata: WatchingMetadata(id: 1, video: 1, season: 1)
      ),
      isDownloaded: true,
      downloadProgress: 1.0,
      isWatched: true,
      watchProgress: 1.0,
      lastWatchTime: 2400
    ),
    EpisodeDownloadInfo(
      groupId: "test",
      episodeNumber: 2,
      episodeTitle: "Второй эпизод",
      downloadUrl: URL(string: "https://example.com/ep2.mp4")!,
      metadata: DownloadMeta(
        id: 2,
        files: [],
        originalTitle: "Test Episode 2",
        localizedTitle: "Тестовый эпизод 2",
        imageUrl: "",
        metadata: WatchingMetadata(id: 2, video: 2, season: 1)
      ),
      isDownloaded: true,
      downloadProgress: 1.0,
      isWatched: false,
      watchProgress: 0.3,
      lastWatchTime: 600
    )
  ]
  
  return SeasonDownloadGroupView(
    seasonGroup: mockSeasonGroup,
    episodes: mockEpisodes,
    activeDownloads: [],
    onToggleExpansion: {},
    onRemoveGroup: {},
    onPauseResumeGroup: {},
    onToggleEpisode: { _ in },
    onPlayEpisode: { _ in },
    onToggleWatchStatus: { _ in }
  )
  .padding()
  .background(Color.KinoPub.background)
} 