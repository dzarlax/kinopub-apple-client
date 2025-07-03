//
//  TabsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend
import AVKit

// MARK: - TV Import (files will be added to Xcode project)

// Temporary TVChannelsView implementation until files are added to Xcode project
struct TVChannelsView: View {
  @StateObject private var viewModel = TVChannelsViewModel()
  @EnvironmentObject var appContext: AppContext
  @State private var selectedChannel: TVChannel?
  
  private let columns = [
    GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
  ]
  
  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(viewModel.channels) { channel in
          TVChannelCard(channel: channel)
            .onTapGesture {
              selectedChannel = channel
            }
        }
      }
      .padding()
    }
    .navigationTitle("ТВ Каналы")
    .refreshable {
      await viewModel.refresh(contentService: appContext.contentService)
    }
    .task {
      await viewModel.loadChannels(contentService: appContext.contentService)
    }
    .alert("Ошибка", isPresented: $viewModel.showError) {
      Button("OK") { viewModel.showError = false }
    } message: {
      Text(viewModel.errorMessage)
    }
    .fullScreenCover(item: $selectedChannel) { channel in
      TVPlayerView(channel: channel)
    }
  }
}

struct TVChannelCard: View {
  let channel: TVChannel
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      AsyncImage(url: URL(string: channel.logos.m)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fit)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay(
            Image(systemName: "tv")
              .font(.largeTitle)
              .foregroundColor(.gray)
          )
      }
      .frame(height: 80)
      .cornerRadius(8)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(channel.title)
          .font(.headline)
          .lineLimit(2)
        
        Text(channel.name)
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack {
          Image(systemName: "dot.radiowaves.left.and.right")
            .foregroundColor(.red)
          Text("Live")
            .font(.caption)
            .foregroundColor(.red)
          
          Spacer()
          
          if let status = channel.status, !status.isEmpty {
            Text(status)
              .font(.caption)
              .padding(4)
              .background(Color.blue.opacity(0.2))
              .cornerRadius(4)
          }
        }
      }
      
      Spacer()
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct TVPlayerView: View {
  let channel: TVChannel
  @State private var player: AVPlayer
  @Environment(\.dismiss) private var dismiss
  @State private var hideNavigationBar = false
  @State private var isPlaying = false
  
  init(channel: TVChannel) {
    self.channel = channel
    self._player = State(initialValue: AVPlayer(url: URL(string: channel.stream)!))
  }
  
  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .top) {
        VideoPlayer(player: player)
          .onAppear(perform: {
            player.play()
            player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { _ in
              isPlaying = player.rate > 0
            }
          })
          .onDisappear(perform: {
            player.pause()
          })
        
        HStack(alignment: .top) {
          Button(action: { dismiss() }, label: {
            HStack(spacing: 8) {
              Image(systemName: "chevron.backward")
                .font(.system(size: 20, weight: .semibold))
              Text("Назад")
                .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
              RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
                .background(
                  RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            )
          })
          .padding(.leading, 20)
          .padding(.top, 20)
          
          Spacer()
          
          VStack(alignment: .trailing, spacing: 4) {
            Text(channel.title)
              .font(.headline)
              .foregroundColor(.white)
            HStack {
              Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundColor(.red)
              Text("Live")
                .font(.caption)
                .foregroundColor(.red)
            }
          }
          .padding(.trailing, 20)
          .padding(.top, 20)
        }
        .background(
          LinearGradient(
            gradient: Gradient(colors: [
              Color.black.opacity(0.6),
              Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 120)
        )
        .opacity(hideNavigationBar ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: hideNavigationBar)
      }
      .ignoresSafeArea(.all)
      .gesture(
        DragGesture()
          .onEnded { value in
            // Свайп вниз для закрытия плеера
            if value.translation.height > 100 {
              dismiss()
            }
          }
      )
      .onTapGesture {
        // Показать/скрыть элементы управления при тапе
        withAnimation(.easeInOut(duration: 0.3)) {
          hideNavigationBar.toggle()
        }
      }
    }
    .ignoresSafeArea(.all)
#if os(iOS)
    .navigationBarHidden(true)
    .toolbar(.hidden, for: .tabBar)
    .onAppear(perform: {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
      AppDelegate.orientationLock = .landscape
    })
    .onDisappear(perform: {
      UIApplication.shared.isIdleTimerDisabled = false
      AppDelegate.orientationLock = .all
      UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
      }
    })
#endif
  }
}

@MainActor
class TVChannelsViewModel: ObservableObject {
  @Published var channels: [TVChannel] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  private var currentPage = 1
  
  func loadChannels(contentService: VideoContentService) async {
    guard !isLoading else { return }
    
    isLoading = true
    
    do {
      let response = try await contentService.fetchTVChannels(page: currentPage)
      channels.append(contentsOf: response.channels)
    } catch {
      if let apiError = error as? APIClientError {
        errorMessage = "Ошибка API: \(apiError.localizedDescription)"
      } else {
        errorMessage = "Ошибка: \(error.localizedDescription)"
      }
      showError = true
    }
    
    isLoading = false
  }
  
  func refresh(contentService: VideoContentService) async {
    channels.removeAll()
    currentPage = 1
    await loadChannels(contentService: contentService)
  }
}

struct TabsNavigationView: View {
  
  @EnvironmentObject var appContext: AppContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  
  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  var body: some View {
    TabView {
      mainTab
      bookmarksTab
      downloadsTab
      tvTab
      collectionsTab
      profileTab
    }
    .accentColor(Color.KinoPub.accent)
    .sheet(isPresented: $authState.shouldShowAuthentication, content: {
      AuthView(model: AuthModel(authService: appContext.authService,
                                authState: authState,
                                errorHandler: errorHandler))
    })
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
    .task {
      Task {
        await authState.check()
      }
    }
  }
  
  var mainTab: some View {
    MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                   authState: authState,
                                   errorHandler: errorHandler))
    .tag(NavigationTabs.main)
    .tabItem {
      Label("Main", systemImage: "house")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var bookmarksTab: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
    .tag(NavigationTabs.bookmarks)
    .tabItem {
      Label("Bookmarks", systemImage: "bookmark")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var downloadsTab: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager, seasonDownloadManager: appContext.seasonDownloadManager))
      .tag(NavigationTabs.downloads)
      .tabItem {
        Label("Downloads", systemImage: "arrow.down.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var tvTab: some View {
    TVChannelsView()
      .environmentObject(appContext)
      .tag(NavigationTabs.tv)
      .tabItem {
        Label("ТВ", systemImage: "tv")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var collectionsTab: some View {
    CollectionsViewTemp()
      .environmentObject(appContext)
      .environmentObject(navigationState)
      .environmentObject(errorHandler)
      .tag(NavigationTabs.collections)
      .tabItem {
        Label("Подборки", systemImage: "photo.stack")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var profileTab: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
      .tag(NavigationTabs.profile)
      .tabItem {
        Label("Profile", systemImage: "person.crop.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}



// MARK: - Temporary Collections Implementation

struct CollectionsViewTemp: View {
  @StateObject private var viewModel = CollectionsViewModelTemp()
  @EnvironmentObject var appContext: AppContext
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var navigationState: NavigationState
  
  var body: some View {
    NavigationStack(path: $navigationState.collectionsRoutes) {
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(viewModel.collections) { collection in
            NavigationLink(value: CollectionsRoutes.collection(collection)) {
              CollectionCardTemp(collection: collection)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding()
      }
      .navigationTitle("Подборки")
      .navigationDestination(for: CollectionsRoutes.self) { route in
        switch route {
        case .collection(let collection):
          CollectionDetailViewTemp(collection: collection)
            .environmentObject(appContext)
            .environmentObject(errorHandler)
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: CollectionsRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: CollectionsRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: CollectionsRoutesLinkProvider()))
        }
      }
      .refreshable {
        await viewModel.refresh(contentService: appContext.contentService)
      }
      .task {
        await viewModel.loadCollections(contentService: appContext.contentService)
      }
      .alert("Ошибка", isPresented: $viewModel.showError) {
        Button("OK") { viewModel.showError = false }
      } message: {
        Text(viewModel.errorMessage)
      }
    }
  }
}

struct CollectionCardTemp: View {
  let collection: Collection
  
  var body: some View {
    HStack(spacing: 16) {
      AsyncImage(url: URL(string: collection.poster ?? "")) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay(
            Image(systemName: "photo.stack")
              .font(.title)
              .foregroundColor(.gray)
          )
      }
      .frame(width: 120, height: 160)
      .clipped()
      .cornerRadius(8)
      
      VStack(alignment: .leading, spacing: 8) {
        Text(collection.title)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        
        if let description = collection.description {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
        
        Spacer()
        
        HStack {
          Image(systemName: "rectangle.stack")
            .foregroundColor(.blue)
          Text("\\(collection.itemsCount) фильмов")
            .font(.caption)
            .foregroundColor(.secondary)
          
          Spacer()
          
          if collection.updatedAt != nil {
            Text("Недавно обновлено")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
  
  private func formatDate(_ dateString: String) -> String {
    let components = dateString.split(separator: "-")
    if components.count >= 3 {
      return "\\(components[2]).\\(components[1]).\\(components[0])"
    }
    return dateString
  }
}

struct CollectionDetailViewTemp: View {
  let collection: Collection
  @StateObject private var viewModel = CollectionDetailViewModelTemp()
  @EnvironmentObject var appContext: AppContext
  @EnvironmentObject var errorHandler: ErrorHandler
  
  private let columns = [
    GridItem(.adaptive(minimum: 150), spacing: 16)
  ]
  
  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(viewModel.items) { item in
          NavigationLink(value: CollectionsRoutes.details(item)) {
            MediaItemTileTemp(item: item)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding()
    }
    .navigationTitle(collection.title)
    .navigationBarTitleDisplayMode(.large)
    .task {
      await viewModel.loadItems(collectionId: collection.id, contentService: appContext.contentService)
    }
    .alert("Ошибка", isPresented: $viewModel.showError) {
      Button("OK") { viewModel.showError = false }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}

struct MediaItemTileTemp: View {
  let item: MediaItem
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Постер
      AsyncImage(url: URL(string: item.posters.medium.isEmpty ? item.posters.small : item.posters.medium)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay(
            Image(systemName: "photo")
              .font(.title2)
              .foregroundColor(.gray)
          )
      }
      .frame(height: 200)
      .clipped()
      .cornerRadius(8)
      
      // Название
      Text(item.title)
        .font(.caption)
        .fontWeight(.medium)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .foregroundColor(.primary)
      
      // Год и рейтинг
      HStack {
        Text(String(item.year))
          .font(.caption2)
          .foregroundColor(.secondary)
        
        Spacer()
        
        if let rating = item.imdbRating, rating > 0 {
          HStack(spacing: 2) {
            Image(systemName: "star.fill")
              .font(.caption2)
              .foregroundColor(.yellow)
            Text(String(format: "%.1f", rating))
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

@MainActor
class CollectionsViewModelTemp: ObservableObject {
  @Published var collections: [Collection] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  private var currentPage = 1
  
  func loadCollections(contentService: VideoContentService) async {
    guard !isLoading else { return }
    
    isLoading = true
    
    do {
      print("🔄 [Collections] Загружаем подборки, страница: \\(currentPage)")
      let response = try await contentService.fetchCollections(page: currentPage)
      print("✅ [Collections] Успешно загружено \\(response.items.count) подборок")
      collections.append(contentsOf: response.items)
    } catch {
      print("❌ [Collections] Ошибка загрузки подборок: \\(error)")
      errorMessage = error.localizedDescription
      showError = true
    }
    
    isLoading = false
  }
  
  func refresh(contentService: VideoContentService) async {
    print("🔄 [Collections] Обновляем подборки")
    collections.removeAll()
    currentPage = 1
    await loadCollections(contentService: contentService)
  }
}

@MainActor
class CollectionDetailViewModelTemp: ObservableObject {
  @Published var items: [MediaItem] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  func loadItems(collectionId: Int, contentService: VideoContentService) async {
    guard !isLoading else { return }
    
    isLoading = true
    
    do {
      print("🔄 [Collection Detail] Загружаем элементы подборки \\(collectionId)")
      let response = try await contentService.fetchCollectionItems(id: collectionId, page: 1)
      print("✅ [Collection Detail] Успешно загружено \\(response.items.count) элементов")
      items = response.items
    } catch {
      print("❌ [Collection Detail] Ошибка загрузки элементов: \\(error)")
      errorMessage = error.localizedDescription
      showError = true
    }
    
    isLoading = false
  }
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
