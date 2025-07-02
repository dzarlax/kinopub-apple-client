import Foundation
import ActivityKit
import os.log

#if os(iOS)
@available(iOS 26.0, *)
public class LiveActivityManager: ObservableObject {
    private let logger = Logger.kit
    private var activeActivities: [String: Activity<DownloadActivityAttributes>] = [:]
    
    public init() {}
    
    // MARK: - Live Activity Management
    
    /// Start a Live Activity for a download
    public func startDownloadActivity<Meta: Codable & Equatable>(
        for download: Download<Meta>,
        itemTitle: String,
        episodeInfo: String? = nil,
        posterUrl: String? = nil,
        totalBytes: Int64 = 0
    ) async {
        // Check if Live Activities are available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("[LIVE_ACTIVITY] Live Activities are not enabled")
            return
        }
        
        let downloadId = download.url.absoluteString
        
        // Check if activity already exists for this download
        if activeActivities[downloadId] != nil {
            logger.info("[LIVE_ACTIVITY] Activity already exists for download: \(downloadId)")
            return
        }
        
        let attributes = DownloadActivityAttributes(
            itemTitle: itemTitle,
            itemId: downloadId,
            episodeInfo: episodeInfo,
            downloadUrl: download.url.absoluteString,
            posterUrl: posterUrl
        )
        
        let downloadedBytes = totalBytes > 0 ? Int64(Double(download.progress) * Double(totalBytes)) : 0
        
        let initialState = DownloadActivityAttributes.ContentState(
            progress: Double(download.progress),
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            downloadSpeed: 0,
            timeRemaining: nil,
            status: mapDownloadState(download.state),
            errorMessage: nil
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: initialState,
                    staleDate: Date().addingTimeInterval(300) // 5 minutes
                ),
                pushType: nil
            )
            
            activeActivities[downloadId] = activity
            logger.info("[LIVE_ACTIVITY] Started Live Activity for download: \(downloadId)")
            
            // TODO: Start observing activity updates
            // observeActivityUpdates(for: activity, downloadId: downloadId)
            
        } catch {
            logger.error("[LIVE_ACTIVITY] Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Update a Live Activity with download progress
    public func updateDownloadActivity<Meta: Codable & Equatable>(
        for download: Download<Meta>,
        downloadSpeed: Int64 = 0,
        timeRemaining: TimeInterval? = nil,
        errorMessage: String? = nil,
        totalBytes: Int64 = 0
    ) async {
        let downloadId = download.url.absoluteString
        
        guard let activity = activeActivities[downloadId] else {
            logger.warning("[LIVE_ACTIVITY] No active activity found for download: \(downloadId)")
            return
        }
        
        let status = mapDownloadState(download.state)
        let downloadedBytes = totalBytes > 0 ? Int64(Double(download.progress) * Double(totalBytes)) : 0
        
        let contentState = DownloadActivityAttributes.ContentState(
            progress: Double(download.progress),
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            downloadSpeed: downloadSpeed,
            timeRemaining: timeRemaining,
            status: status,
            errorMessage: errorMessage
        )
        
        let content = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes
        )
        
        await activity.update(content)
        logger.debug("[LIVE_ACTIVITY] Updated Live Activity for download: \(downloadId)")
    }
    
    /// End a Live Activity for a download
    public func endDownloadActivity(
        for downloadId: String,
        finalStatus: DownloadActivityAttributes.ContentState.DownloadStatus = .completed,
        dismissalPolicy: ActivityUIDismissalPolicy = .default
    ) async {
        guard let activity = activeActivities[downloadId] else {
            logger.warning("[LIVE_ACTIVITY] No active activity found for download: \(downloadId)")
            return
        }
        
        // Create final content state
        let finalContent = DownloadActivityAttributes.ContentState(
            progress: finalStatus == .completed ? 1.0 : activity.content.state.progress,
            downloadedBytes: activity.content.state.downloadedBytes,
            totalBytes: activity.content.state.totalBytes,
            downloadSpeed: 0,
            timeRemaining: nil,
            status: finalStatus,
            errorMessage: finalStatus == .failed ? "Download failed" : nil
        )
        
        await activity.end(
            ActivityContent(
                state: finalContent,
                staleDate: nil
            ),
            dismissalPolicy: dismissalPolicy
        )
        
        activeActivities.removeValue(forKey: downloadId)
        logger.info("[LIVE_ACTIVITY] Ended Live Activity for download: \(downloadId)")
    }
    
    /// End all active Live Activities
    public func endAllActivities() async {
        logger.info("[LIVE_ACTIVITY] Ending all active Live Activities")
        
        for (_, activity) in activeActivities {
            let finalContent = DownloadActivityAttributes.ContentState(
                progress: activity.content.state.progress,
                downloadedBytes: activity.content.state.downloadedBytes,
                totalBytes: activity.content.state.totalBytes,
                downloadSpeed: 0,
                timeRemaining: nil,
                status: .completed,
                errorMessage: nil
            )
            
            await activity.end(
                ActivityContent(
                    state: finalContent,
                    staleDate: nil
                ),
                dismissalPolicy: .default
            )
        }
        
        activeActivities.removeAll()
    }
    
    /// Check if Live Activities are available
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Get count of active Live Activities
    public var activeActivityCount: Int {
        activeActivities.count
    }
    
    // MARK: - Private Methods
    
    private func observeActivityUpdates(for activity: Activity<DownloadActivityAttributes>, downloadId: String) {
        // TODO: Implement activity state observation
        // This would monitor activity.activityStateUpdates and clean up when dismissed/ended
        logger.debug("[LIVE_ACTIVITY] Activity observation setup for download: \(downloadId)")
    }
    
    // MARK: - Helper Methods
    
    private func mapDownloadState<Meta: Codable & Equatable>(_ state: Download<Meta>.State) -> DownloadActivityAttributes.ContentState.DownloadStatus {
        switch state {
        case .notStarted, .queued:
            return .queued
        case .inProgress:
            return .downloading
        case .paused:
            return .paused
        }
    }
}

// MARK: - DownloadActivityAttributes (moved from Widget Extension for shared access)

/// Attributes that describe the static and dynamic data for a download Live Activity
public struct DownloadActivityAttributes: ActivityAttributes {
    /// Dynamic data that changes during the activity
    public struct ContentState: Codable, Hashable {
        /// Current download progress (0.0 to 1.0)
        public var progress: Double
        /// Downloaded bytes
        public var downloadedBytes: Int64
        /// Total bytes to download
        public var totalBytes: Int64
        /// Download speed in bytes per second
        public var downloadSpeed: Int64
        /// Estimated time remaining in seconds
        public var timeRemaining: TimeInterval?
        /// Current download status
        public var status: DownloadStatus
        /// Optional error message
        public var errorMessage: String?
        
        public enum DownloadStatus: String, Codable, CaseIterable {
            case downloading = "downloading"
            case paused = "paused"
            case completed = "completed"
            case failed = "failed"
            case queued = "queued"
        }
        
        public init(
            progress: Double,
            downloadedBytes: Int64,
            totalBytes: Int64,
            downloadSpeed: Int64,
            timeRemaining: TimeInterval?,
            status: DownloadStatus,
            errorMessage: String?
        ) {
            self.progress = progress
            self.downloadedBytes = downloadedBytes
            self.totalBytes = totalBytes
            self.downloadSpeed = downloadSpeed
            self.timeRemaining = timeRemaining
            self.status = status
            self.errorMessage = errorMessage
        }
    }
    
    /// Static information about the download
    public let itemTitle: String
    public let itemId: String
    public let episodeInfo: String? // e.g. "S1E1" or nil for movies
    public let downloadUrl: String
    public let posterUrl: String?
    
    public init(
        itemTitle: String,
        itemId: String,
        episodeInfo: String?,
        downloadUrl: String,
        posterUrl: String?
    ) {
        self.itemTitle = itemTitle
        self.itemId = itemId
        self.episodeInfo = episodeInfo
        self.downloadUrl = downloadUrl
        self.posterUrl = posterUrl
    }
}

#endif 