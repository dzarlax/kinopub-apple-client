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
  @StateObject private var itemModel: MediaItemModel
  
  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
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
                                       onWatchedToggle: {},
                                       onBookmarkHandle: {})
              MediaItemFieldsCard(mediaItem: mediaItem, isSkeleton: itemModel.isLoading)
            } else {
              // Show skeleton loading view when no data
              MediaItemDescriptionCard(mediaItem: MediaItem.mock(), 
                                       isSkeleton: true,
                                       onDownload: { _, _ in },
                                       onWatchedToggle: {},
                                       onBookmarkHandle: {})
              MediaItemFieldsCard(mediaItem: MediaItem.mock(), isSkeleton: true)
            }
          }
          .containerShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .fixedSize(horizontal: false, vertical: true)
          .padding([.horizontal, .bottom], 16)
          .frame(maxWidth: 1200, minHeight: 400)
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
  }
  
  var headerView: some View {
    MediaItemHeaderView(size: .standard,
                        mediaItem: itemModel.mediaItem ?? MediaItem.mock(),
                        linkProvider: itemModel.linkProvider,
                        isSkeleton: itemModel.isLoading)
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
