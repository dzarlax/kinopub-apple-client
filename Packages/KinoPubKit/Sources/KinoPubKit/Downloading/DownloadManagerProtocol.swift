//
//  DownloadManagerProtocol.swift
//  KinoPubKit
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation

// MARK: - Download Manager Protocol
public protocol DownloadManagerProtocol: AnyObject {
  func resumeAllDownloads()
  func pauseAllDownloads()
  var activeDownloadCount: Int { get }
}

// MARK: - Protocol Extension
extension DownloadManager: DownloadManagerProtocol {
  public var activeDownloadCount: Int {
    return activeDownloads.count
  }
} 