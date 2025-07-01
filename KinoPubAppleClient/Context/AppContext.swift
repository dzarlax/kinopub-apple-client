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

// MARK: - AppContext

struct AppContext: AppContextProtocol {
  
  var configuration: Configuration
  var authService: AuthorizationService
  var contentService: VideoContentService
  var accessTokenService: AccessTokenService
  var userService: UserService
  var keychainStorage: KeychainStorage
  var fileSaver: FileSaving
  var downloadManager: DownloadManager<DownloadMeta>
  var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  var actionsService: UserActionsService
  
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
      actionsService: UserActionsServiceImpl(apiClient: apiClient)
    )
    
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
  @available(iOS 13.0, *)
  var backgroundTaskManager: BackgroundTaskManager? {
    return downloadManager.backgroundTaskManager
  }
  
  /// Get notification manager (iOS only)
  @available(iOS 10.0, *)
  var notificationManager: DownloadNotificationManager? {
    return downloadManager.notificationManager
  }
  #endif
}
