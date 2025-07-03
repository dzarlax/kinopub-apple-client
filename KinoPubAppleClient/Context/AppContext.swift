//
//  AppContext.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubLogging
import OSLog
// import ActivityKit  // Временно отключено

#if os(iOS)
import UIKit
#endif

// MARK: - Env key

private struct AppContextKey: EnvironmentKey {
  static let defaultValue: AppContextProtocol = AppContext.shared
}

extension EnvironmentValues {
  var appContext: AppContextProtocol {
    get { self[AppContextKey.self] }
    set { self[AppContextKey.self] = newValue }
  }
}

// MARK: - Background Downloads Provider

protocol BackgroundDownloadsProvider {
  func enableBackgroundDownloads() async -> Bool
  var isBackgroundDownloadsEnabled: Bool { get }
  
  #if os(iOS)
  var backgroundTaskManager: BackgroundTaskManager? { get }
  var notificationManager: DownloadNotificationManager? { get }
  // @available(iOS 26.0, *)
  // var liveActivityManager: LiveActivityManager? { get }  // Временно отключено
  #endif
}

// MARK: - AppContextProtocol

typealias AppContextProtocol = AuthorizationServiceProvider
& VideoContentServiceProvider
& ConfigurationProvider
& KeychainStorageProvider
& AccessTokenServiceProvider
& DownloadManagerProvider
& DownloadedFilesDatabaseProvider
& FileSaverProvider
& UserServiceProvider
& UserActionsServiceProvider
& BackgroundDownloadsProvider

// MARK: - AppContext

class AppContext: AppContextProtocol, ObservableObject {
  
  var configuration: Configuration
  var authService: AuthorizationService
  var contentService: VideoContentService
  var accessTokenService: AccessTokenService
  var userService: UserService
  var keychainStorage: KeychainStorage
  var fileSaver: FileSaving
  var downloadManager: DownloadManager<DownloadMeta>
  var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  var seasonDownloadManager: SeasonDownloadManager
  var actionsService: UserActionsService
  
  #if os(iOS)
  // @available(iOS 26.0, *)
  // var liveActivityManager: LiveActivityManager?  // Временно отключено
  #endif
  
  init(
    configuration: Configuration,
    authService: AuthorizationService,
    contentService: VideoContentService,
    accessTokenService: AccessTokenService,
    userService: UserService,
    keychainStorage: KeychainStorage,
    fileSaver: FileSaving,
    downloadManager: DownloadManager<DownloadMeta>,
    downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
    seasonDownloadManager: SeasonDownloadManager,
    actionsService: UserActionsService
  ) {
    self.configuration = configuration
    self.authService = authService
    self.contentService = contentService
    self.accessTokenService = accessTokenService
    self.userService = userService
    self.keychainStorage = keychainStorage
    self.fileSaver = fileSaver
    self.downloadManager = downloadManager
    self.downloadedFilesDatabase = downloadedFilesDatabase
    self.seasonDownloadManager = seasonDownloadManager
    self.actionsService = actionsService
  }
  
  static let shared: AppContext = {
    let configuration = BundleConfiguration()
    let keychainStorage = KeychainStorageImpl()
    let accessTokenService = AccessTokenServiceImpl(storage: keychainStorage)
    
    // Downloads
    let fileSaver = FileSaver()
    let downloadedFilesDatabase = DownloadedFilesDatabase<DownloadMeta>(fileSaver: fileSaver)
    
    // Enhanced DownloadManager with background support
    let downloadManager = DownloadManager<DownloadMeta>(
      fileSaver: fileSaver, 
      database: downloadedFilesDatabase,
      maxConcurrentDownloads: 3,
      timeoutInterval: 60.0,
      backgroundSessionIdentifier: "com.kinopub.backgroundDownloadSession"
    )
    
    // Season Download Manager
    let seasonDownloadManager = SeasonDownloadManager(
      downloadManager: downloadManager,
      fileSaver: fileSaver
    )
    
    // Api Client with caching
    let cacheManager = MemoryCacheManager()
    let apiClient = makeApiClient(
      with: configuration.baseURL, 
      accessTokenService: accessTokenService,
      cacheManager: cacheManager
    )
    
    let authService = AuthorizationServiceImpl(
      apiClient: apiClient,
      configuration: configuration,
      accessTokenService: accessTokenService
    )
    
    #if os(iOS)
    // let liveActivityManager: LiveActivityManager?  // Временно отключено
    // if #available(iOS 26.0, *) {
    //   liveActivityManager = LiveActivityManager()
    // } else {
    //   liveActivityManager = nil
    // }
    #endif
    
    #if os(iOS)
    let context = AppContext(
      configuration: configuration,
      authService: authService,
      contentService: VideoContentServiceImpl(apiClient: apiClient),
      accessTokenService: accessTokenService,
      userService: UserServiceImpl(apiClient: apiClient),
      keychainStorage: keychainStorage,
      fileSaver: fileSaver,
      downloadManager: downloadManager,
      downloadedFilesDatabase: downloadedFilesDatabase,
      seasonDownloadManager: seasonDownloadManager,
      actionsService: UserActionsServiceImpl(apiClient: apiClient)
      // liveActivityManager: liveActivityManager  // Временно отключено
    )
    #else
    let context = AppContext(
      configuration: configuration,
      authService: authService,
      contentService: VideoContentServiceImpl(apiClient: apiClient),
      accessTokenService: accessTokenService,
      userService: UserServiceImpl(apiClient: apiClient),
      keychainStorage: keychainStorage,
      fileSaver: fileSaver,
      downloadManager: downloadManager,
      downloadedFilesDatabase: downloadedFilesDatabase,
      seasonDownloadManager: seasonDownloadManager,
      actionsService: UserActionsServiceImpl(apiClient: apiClient)
    )
    #endif
    
    // Setup background downloads
    setupBackgroundDownloads(downloadManager: downloadManager)
    
    return context
  }()
  
  // MARK: - API Client building
  
  private static func makeApiClient(
    with baseURL: String, 
    accessTokenService: AccessTokenService,
    cacheManager: CacheManaging
  ) -> APIClient {
    APIClient(
      baseUrl: baseURL,
      plugins: [
        CURLLoggingPlugin(),
        ResponseLoggingPlugin(),
        AccessTokenPlugin(accessTokenService: accessTokenService)
      ],
      cacheManager: cacheManager
    )
  }
  
  // MARK: - Background Downloads Setup
  
  private static func setupBackgroundDownloads(downloadManager: DownloadManager<DownloadMeta>) {
    #if os(iOS)
    // Configure AppDelegate with download manager
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.setDownloadManager(downloadManager)
      Logger.app.info("[CONTEXT] Download manager configured with AppDelegate")
    }
    
    // Enable background downloads
    Task {
      let enabled = await downloadManager.enableBackgroundDownloads()
      if enabled {
        Logger.app.info("[CONTEXT] Background downloads enabled successfully")
      } else {
        Logger.app.warning("[CONTEXT] Failed to enable background downloads")
      }
    }
    #endif
  }
}

// MARK: - Public Methods for Background Downloads
extension AppContext {
  
  /// Request permission for background downloads and notifications
  func enableBackgroundDownloads() async -> Bool {
    #if os(iOS)
    return await downloadManager.enableBackgroundDownloads()
    #else
    return false
    #endif
  }
  
  /// Check if background downloads are available and enabled
  var isBackgroundDownloadsEnabled: Bool {
    #if os(iOS)
    return downloadManager.backgroundDownloadsEnabled
    #else
    return false
    #endif
  }
  
  /// Get background task manager (iOS only)
  #if os(iOS)
  var backgroundTaskManager: BackgroundTaskManager? {
    return downloadManager.backgroundTaskManager
  }
  
  /// Get notification manager (iOS only)
  var notificationManager: DownloadNotificationManager? {
    return downloadManager.notificationManager
  }
  
  #endif
  
  // MARK: - Mock for testing
  static func mock() -> AppContext {
    return AppContext.shared
  }
}
