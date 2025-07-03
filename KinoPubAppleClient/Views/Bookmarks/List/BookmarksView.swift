//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI
import SkeletonUI

struct BookmarksView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var appContext: AppContext
  @StateObject private var catalog: BookmarksCatalog
  
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
    List(catalog.items) { bookmark in
      NavigationLink(value: BookmarksRoutes.bookmark(bookmark)) {
        Text(bookmark.title)
      }
    }
    .scrollContentBackground(.hidden)
  }
}

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: VideoContentServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
