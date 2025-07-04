//
//  MediaItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubKit
import SkeletonUI

struct MediaItemView: View {
  
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var appContext: AppContext
  @StateObject private var itemModel: MediaItemModel
  @State private var showComments = false
  @State private var userRating: Int = 5
  @State private var hasVoted = false
  
  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
  }
  
  init(id: String) {
    // Создаем временную модель
    _itemModel = StateObject(wrappedValue: MediaItemModel(
      mediaItemId: Int(id) ?? 0,
      itemsService: VideoContentServiceMock(),
      downloadManager: DownloadManager<DownloadMeta>(
        fileSaver: FileSaver(),
        database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())
      ),
      linkProvider: MainRoutesLinkProvider(),
      errorHandler: ErrorHandler()
    ))
  }
  
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var sizeClass
#endif
  
  var toolbarItemPlacement: ToolbarItemPlacement {
#if os(iOS)
    .topBarTrailing
#elseif os(macOS)
    .navigation
#endif
  }
  
  var body: some View {
    WidthThresholdReader(widthThreshold: 520) { _ in
      ScrollView(.vertical) {
        VStack(spacing: 16) {
          headerView
          Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            if let mediaItem = itemModel.mediaItem {
              MediaItemDescriptionCard(mediaItem: mediaItem, 
                                       isSkeleton: itemModel.isLoading,
                                       onDownload: { itemModel.startDownload(item: $0, file: $1) },
                                       onSeasonDownload: { mediaItem, season in
                                         itemModel.startSeasonDownload(mediaItem: mediaItem, season: season)
                                       })
              MediaItemFieldsCard(mediaItem: mediaItem, isSkeleton: itemModel.isLoading)
            } else {
              // Show skeleton loading view when no data
              MediaItemDescriptionCard(mediaItem: MediaItem.mock(), 
                                       isSkeleton: true,
                                       onDownload: { _, _ in },
                                       onSeasonDownload: nil)
              MediaItemFieldsCard(mediaItem: MediaItem.mock(), isSkeleton: true)
            }
          }
          .containerShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 16)
          
          // New sections
          if let mediaItem = itemModel.mediaItem {
            // Voting section
            VotingCard(
              mediaItem: mediaItem,
              userRating: $userRating,
              hasVoted: $hasVoted,
              onVote: { rating in
                Task {
                  await submitVote(mediaId: mediaItem.id, rating: rating)
                }
              }
            )
            .padding(.horizontal, 16)
            
            // Action buttons
            HStack(spacing: 16) {
              Button(action: {
                showComments = true
              }) {
                Label("Комментарии", systemImage: "bubble.left.and.bubble.right")
              }
              .buttonStyle(.bordered)
              

              
              Spacer()
            }
            .padding(.horizontal, 16)
            
            // Similar videos section
            SimilarVideosSection(mediaId: mediaItem.id)
              .padding(.horizontal, 16)
          }
          
          Spacer(minLength: 100) // Bottom padding for scroll
        }
      }
    }
    .background(Color.KinoPub.background)
    .background()
    #if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    #endif
    .task {
      await itemModel.fetchData()
    }
    .handleError(state: $errorHandler.state)
    .sheet(isPresented: $showComments) {
      if let mediaItem = itemModel.mediaItem {
        CommentsView(
          mediaId: mediaItem.id,
          videoId: Optional<Int>.none,
          seasonId: Optional<Int>.none
        )
        .environmentObject(appContext)
      }
    }

  }
  
  var headerView: some View {
    MediaItemHeaderView(size: .standard,
                        mediaItem: itemModel.mediaItem ?? MediaItem.mock(),
                        linkProvider: itemModel.linkProvider,
                        isSkeleton: itemModel.isLoading)
  }
  
  private func submitVote(mediaId: Int, rating: Int) async {
    do {
      _ = try await appContext.contentService.voteForVideo(id: mediaId, rating: rating)
      hasVoted = true
    } catch {
      errorHandler.setError(error)
    }
  }
}

// MARK: - New Components

struct VotingCard: View {
  let mediaItem: MediaItem
  @Binding var userRating: Int
  @Binding var hasVoted: Bool
  let onVote: (Int) -> Void
  
  var body: some View {
    VStack(spacing: 12) {
      Text("Оцените фильм")
        .font(.headline)
      
      HStack {
        ForEach(1...10, id: \.self) { rating in
          Button(action: {
            userRating = rating
          }) {
            Image(systemName: rating <= userRating ? "star.fill" : "star")
              .foregroundColor(rating <= userRating ? .yellow : .gray)
              .font(.title2)
          }
          .disabled(hasVoted)
        }
      }
      
      if !hasVoted {
        Button("Голосовать") {
          onVote(userRating)
        }
        .buttonStyle(.borderedProminent)
        .disabled(userRating == 0)
      } else {
        Text("Спасибо за вашу оценку!")
          .foregroundColor(.green)
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

// MARK: - MediaItemViewWrapper для правильной работы с AppContext
struct MediaItemViewWrapper: View {
  let mediaItemId: String
  
  @EnvironmentObject var appContext: AppContext
  @EnvironmentObject var errorHandler: ErrorHandler
  
  var body: some View {
    MediaItemView(model: MediaItemModel(
      mediaItemId: Int(mediaItemId) ?? 0,
      itemsService: appContext.contentService,
      downloadManager: appContext.downloadManager,
      linkProvider: MainRoutesLinkProvider(),
      errorHandler: errorHandler
    ))
  }
}

struct SimilarVideosSection: View {
  let mediaId: Int
  @StateObject private var viewModel = SimilarVideosViewModel()
  @EnvironmentObject var appContext: AppContext
  
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
  ]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Похожие фильмы")
        .font(.headline)
      
      if viewModel.items.isEmpty && !viewModel.isLoading {
        Text("Нет похожих фильмов")
          .foregroundColor(.secondary)
      } else {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(viewModel.items.prefix(6)) { item in
            NavigationLink(destination: MediaItemViewWrapper(mediaItemId: String(item.id))) {
              SimilarItemCard(item: item)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
    }
    .task {
      await viewModel.loadSimilarVideos(
        mediaId: mediaId,
        contentService: appContext.contentService
      )
    }
  }
}

// MARK: - Similar Videos ViewModel

@MainActor
class SimilarVideosViewModel: ObservableObject {
  @Published var items: [MediaItem] = []
  @Published var isLoading = false
  
  func loadSimilarVideos(mediaId: Int, contentService: VideoContentService) async {
    guard !isLoading else { return }
    
    isLoading = true
    
    do {
      let response = try await contentService.fetchSimilarVideos(for: mediaId, page: 1)
      items = response.items
    } catch {
      print("Error loading similar videos: \(error)")
    }
    
    isLoading = false
  }
}

// MARK: - Similar Item Card

struct SimilarItemCard: View {
  let item: MediaItem
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      AsyncImage(url: URL(string: item.posters.big.isEmpty ? "" : item.posters.big)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.3))
          .overlay(
            Image(systemName: "photo")
              .foregroundColor(.gray)
          )
      }
      .frame(height: 180)
      .clipped()
      .cornerRadius(8)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.caption.bold())
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        
        if item.year > 0 {
          Text("\(item.year)")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        
        if let rating = item.kinopoiskRating {
          HStack(spacing: 2) {
            Image(systemName: "star.fill")
              .foregroundColor(.yellow)
              .font(.caption2)
            Text(String(format: "%.1f", rating))
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Temporary CommentsView Stub
struct CommentsView: View {
  let mediaId: Int
  let videoId: Int?
  let seasonId: Int?
  
  @EnvironmentObject var appContext: AppContext
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack {
        Text("Комментарии")
          .font(.title)
        Text("Пока не реализовано")
          .foregroundColor(.secondary)
        Spacer()
      }
      .navigationTitle("Комментарии")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Готово") {
            dismiss()
          }
        }
      }
    }
  }
}

struct MediaItemView_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemView(model: MediaItemModel(mediaItemId: MediaItem.mock().id,
                                          itemsService: VideoContentServiceMock(),
                                          downloadManager: DownloadManager<DownloadMeta>(fileSaver: FileSaver(),
                                                                                      database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())),
                                          linkProvider: MainRoutesLinkProvider(),
                                          errorHandler: ErrorHandler()))
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
