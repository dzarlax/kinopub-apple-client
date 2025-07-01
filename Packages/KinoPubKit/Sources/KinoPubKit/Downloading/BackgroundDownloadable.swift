//
//  BackgroundDownloadable.swift
//  KinoPubKit
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation

// MARK: - Background Downloadable Protocol
public protocol BackgroundDownloadable: AnyObject {
  func resumeAllDownloads()
  func pauseAllDownloads()
  var activeDownloadsCount: Int { get }
}

// MARK: - DownloadManager Conformance
extension DownloadManager: BackgroundDownloadable {
  public var activeDownloadsCount: Int {
    return activeDownloads.count
  }
} 