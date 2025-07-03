//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI
import SkeletonUI
import KinoPubBackend

struct BookmarksView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var appContext: AppContext
  @StateObject private var catalog: BookmarksCatalog
  @State private var expandedBookmarks: Set<Int> = []
  @State private var bookmarkModels: [Int: BookmarkModel] = [:]
  
  init(catalog: @autoclosure @escaping () -> BookmarksCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.bookmarksRoutes) {
      VStack {
        bookmarksList
      }
      .navigationTitle("Bookmarks")
      .background(Color.KinoPub.background)
      .refreshable(action: catalog.refresh)
      .task {
        await catalog.fetchItems()
      }
      .navigationDestination(for: BookmarksRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: BookmarksRoutesLinkProvider(),
                                              errorHandler: errorHandler))
        case .bookmark(let bookmark):
          // Этот route больше не используется, но оставляем для совместимости
          BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                            itemsService: appContext.contentService,
                                            errorHandler: errorHandler))
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
        case .seasons(let seasons):
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: BookmarksRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: BookmarksRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
    }
  }
  
  var bookmarksList: some View {
    List {
      ForEach(catalog.items) { bookmark in
        DisclosureGroup(
          isExpanded: Binding(
            get: { expandedBookmarks.contains(bookmark.id) },
            set: { isExpanded in
              if isExpanded {
                expandedBookmarks.insert(bookmark.id)
                // Создаем модель для закладки если её ещё нет
                if bookmarkModels[bookmark.id] == nil {
                  let model = BookmarkModel(
                    bookmark: bookmark,
                    itemsService: appContext.contentService,
                    errorHandler: errorHandler
                  )
                  bookmarkModels[bookmark.id] = model
                  // Загружаем элементы закладки
                  Task {
                    await model.fetchItems()
                  }
                }
              } else {
                expandedBookmarks.remove(bookmark.id)
              }
            }
          )
        ) {
          // Содержимое закладки
          if let model = bookmarkModels[bookmark.id] {
            BookmarkContentView(model: model)
          }
        } label: {
          HStack {
            Text(bookmark.title)
              .font(.headline)
              .foregroundColor(.KinoPub.text)
            Spacer()
          }
          .padding(.vertical, 8)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .listStyle(.inset)
  }
}

// MARK: - BookmarkContentView

struct BookmarkContentView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var appContext: AppContext
  @ObservedObject var model: BookmarkModel
  
  var body: some View {
    LazyVStack(spacing: 12) {
      ForEach(model.items) { item in
        MediaItemRow(item: item)
          .onTapGesture {
            navigationState.bookmarksRoutes.append(.details(item))
          }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }
}

struct MediaItemRow: View {
  let item: MediaItem
  
  var body: some View {
    HStack(spacing: 12) {
      // Постер
      AsyncImage(url: URL(string: item.posters.small)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
      }
      .frame(width: 60, height: 90)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      
      // Информация
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.KinoPub.text)
          .lineLimit(2)
        
        Text("\(item.year)")
          .font(.caption)
          .foregroundColor(.KinoPub.subtitle)
        
        if !item.genres.isEmpty {
          Text(item.genres.compactMap { $0.title }.joined(separator: ", "))
            .font(.caption)
            .foregroundColor(.KinoPub.subtitle)
            .lineLimit(1)
        }
        
        Spacer()
      }
      
      Spacer()
      
      // Стрелка
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.gray)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.KinoPub.background)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    )
  }
}

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: VideoContentServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
