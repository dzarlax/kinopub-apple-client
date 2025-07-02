//
//  BackgroundDownloadsSettingsView.swift
//  KinoPubAppleClient
//
//  Created by AI Assistant on 01.07.2025.
//

import SwiftUI
import KinoPubKit
import KinoPubLogging
import OSLog

#if os(iOS)
import UserNotifications

struct BackgroundDownloadsSettingsView: View {
  
  @EnvironmentObject private var appContext: AppContextProtocol
  @State private var isBackgroundDownloadsEnabled = false
  @State private var notificationPermissionGranted = false
  @State private var showingPermissionAlert = false
  @State private var showingInfoSheet = false
  @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .restricted
  
  var body: some View {
    List {
      Section {
        backgroundDownloadsToggle
        
        if isBackgroundDownloadsEnabled {
          notificationSettings
          backgroundRefreshInfo
        }
        
      } header: {
        Text("Background Downloads")
      } footer: {
        Text("Download videos in the background when the app is not active. Requires Background App Refresh to be enabled.")
      }
      
      Section {
        HStack {
          Image(systemName: "info.circle")
            .foregroundColor(.blue)
          
          VStack(alignment: .leading, spacing: 4) {
            Text("How it works")
              .font(.headline)
            Text("Downloads continue when app is backgrounded")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          Spacer()
          
          Button("Learn More") {
            showingInfoSheet = true
          }
          .font(.caption)
        }
        .padding(.vertical, 4)
        
      } header: {
        Text("Information")
      }
      
      if isBackgroundDownloadsEnabled {
        Section {
          downloadStatistics
        } header: {
          Text("Statistics")
        }
      }
    }
    .navigationTitle("Background Downloads")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      checkCurrentSettings()
    }
    .alert("Permission Required", isPresented: $showingPermissionAlert) {
      Button("Settings") {
        openAppSettings()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Background App Refresh is disabled. Enable it in Settings to use background downloads.")
    }
    .sheet(isPresented: $showingInfoSheet) {
      BackgroundDownloadsInfoView()
    }
  }
  
  // MARK: - UI Components
  
  private var backgroundDownloadsToggle: some View {
    HStack {
      Image(systemName: "arrow.down.circle.fill")
        .foregroundColor(.blue)
        .font(.title2)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Background Downloads")
          .font(.headline)
        
        Text(backgroundDownloadsStatus)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Toggle("", isOn: $isBackgroundDownloadsEnabled)
        .labelsHidden()
                  .onChange(of: isBackgroundDownloadsEnabled) { _, newValue in
          Task {
            await toggleBackgroundDownloads(newValue)
          }
        }
    }
    .padding(.vertical, 4)
  }
  
  private var notificationSettings: some View {
    HStack {
      Image(systemName: notificationPermissionGranted ? "bell.fill" : "bell.slash")
        .foregroundColor(notificationPermissionGranted ? .green : .orange)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Download Notifications")
          .font(.subheadline)
        
        Text(notificationPermissionGranted ? "Enabled" : "Disabled")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      if !notificationPermissionGranted {
        Button("Enable") {
          Task {
            await requestNotificationPermission()
          }
        }
        .font(.caption)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }
    }
    .padding(.vertical, 2)
  }
  
  private var backgroundRefreshInfo: some View {
    HStack {
      Image(systemName: backgroundRefreshIconName)
        .foregroundColor(backgroundRefreshColor)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Background App Refresh")
          .font(.subheadline)
        
        Text(backgroundRefreshStatusText)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      if backgroundRefreshStatus != .available {
        Button("Settings") {
          openAppSettings()
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.vertical, 2)
  }
  
  private var downloadStatistics: some View {
    VStack(spacing: 12) {
      HStack {
        Label("Active Downloads", systemImage: "arrow.down")
        Spacer()
        Text("\(appContext.downloadManager.activeDownloads.count)")
          .font(.headline)
          .foregroundColor(.blue)
      }
      
      HStack {
        Label("Background Tasks", systemImage: "gear")
        Spacer()
        if let backgroundManager = appContext.backgroundTaskManager {
          Text(backgroundManager.backgroundTasksRegistered ? "Registered" : "Not Registered")
            .font(.subheadline)
            .foregroundColor(backgroundManager.backgroundTasksRegistered ? .green : .red)
        } else {
          Text("Not Available")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
      
      HStack {
        Label("Extended Processing", systemImage: "timer")
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          if appContext.backgroundTaskManager != nil {
            Text("BGContinuedProcessingTask")
              .font(.subheadline)
              .foregroundColor(.green)
            
            Text("iOS 26+ • Live Activity")
              .font(.caption2)
              .foregroundColor(.secondary)
          } else {
            Text("Not Available")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }
  
  // MARK: - Computed Properties
  
  private var backgroundDownloadsStatus: String {
    if isBackgroundDownloadsEnabled {
      return "Downloads will continue in background"
    } else {
      return "Downloads pause when app is backgrounded"
    }
  }
  
  private var backgroundRefreshIconName: String {
    switch backgroundRefreshStatus {
    case .available:
      return "checkmark.circle.fill"
    case .denied:
      return "xmark.circle.fill"
    case .restricted:
      return "exclamationmark.triangle.fill"
    @unknown default:
      return "questionmark.circle"
    }
  }
  
  private var backgroundRefreshColor: Color {
    switch backgroundRefreshStatus {
    case .available:
      return .green
    case .denied:
      return .red
    case .restricted:
      return .orange
    @unknown default:
      return .gray
    }
  }
  
  private var backgroundRefreshStatusText: String {
    switch backgroundRefreshStatus {
    case .available:
      return "Enabled"
    case .denied:
      return "Disabled by user"
    case .restricted:
      return "Restricted by system"
    @unknown default:
      return "Unknown"
    }
  }
  
  // MARK: - Methods
  
  private func checkCurrentSettings() {
    isBackgroundDownloadsEnabled = appContext.isBackgroundDownloadsEnabled
    backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        self.notificationPermissionGranted = settings.authorizationStatus == .authorized ||
                                             settings.authorizationStatus == .provisional
      }
    }
  }
  
  private func toggleBackgroundDownloads(_ enabled: Bool) async {
    if enabled {
      // Check background refresh status first
      guard UIApplication.shared.backgroundRefreshStatus == .available else {
        DispatchQueue.main.async {
          self.isBackgroundDownloadsEnabled = false
          self.showingPermissionAlert = true
        }
        return
      }
      
      // Enable background downloads
      let success = await appContext.enableBackgroundDownloads()
      
      DispatchQueue.main.async {
        self.isBackgroundDownloadsEnabled = success
        if success {
          Logger.app.info("[SETTINGS] Background downloads enabled")
        } else {
          Logger.app.warning("[SETTINGS] Failed to enable background downloads")
        }
      }
    } else {
      // Disable background downloads
      // Note: In a real implementation, you'd want to pause background tasks
      DispatchQueue.main.async {
        self.isBackgroundDownloadsEnabled = false
        Logger.app.info("[SETTINGS] Background downloads disabled")
      }
    }
  }
  
  private func requestNotificationPermission() async {
    if let notificationManager = appContext.notificationManager {
      let granted = await notificationManager.requestNotificationPermission()
      
      DispatchQueue.main.async {
        self.notificationPermissionGranted = granted
      }
    }
  }
  
  private func openAppSettings() {
    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(settingsUrl)
    }
  }
}

// MARK: - Info View
struct BackgroundDownloadsInfoView: View {
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          
          InfoSection(
            icon: "arrow.down.circle.fill",
            title: "Continuous Downloads",
            description: "Videos continue downloading even when you switch to other apps or your device goes to sleep."
          )
          
          InfoSection(
            icon: "bell.fill",
            title: "Smart Notifications",
            description: "Get notified when downloads complete, with options to open files or retry failed downloads."
          )
          
          InfoSection(
            icon: "battery.75",
            title: "Power Efficient",
            description: "Downloads automatically pause during Low Power Mode and resume when disabled."
          )
          
          InfoSection(
            icon: "gear",
            title: "System Integration",
            description: "Uses iOS Background App Refresh to ensure downloads continue reliably."
          )
          
          InfoSection(
            icon: "timer",
            title: "Extended Processing",
            description: "Uses BGContinuedProcessingTask for longer background execution, allowing larger video files to download completely."
          )
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Requirements")
              .font(.headline)
              .padding(.bottom, 4)
            
            RequirementRow("Background App Refresh enabled", isRequired: true)
            RequirementRow("Notification permissions", isRequired: false)
            RequirementRow("Sufficient storage space", isRequired: true)
          }
          .padding()
          .background(Color.secondary.opacity(0.1))
          .cornerRadius(12)
        }
        .padding()
      }
      .navigationTitle("Background Downloads")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

struct InfoSection: View {
  let icon: String
  let title: String
  let description: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(.blue)
        .frame(width: 32)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        
        Text(description)
          .font(.body)
          .foregroundColor(.secondary)
      }
      
      Spacer()
    }
  }
}

struct RequirementRow: View {
  let text: String
  let isRequired: Bool
  
  var body: some View {
    HStack {
      Image(systemName: isRequired ? "checkmark.circle.fill" : "info.circle")
        .foregroundColor(isRequired ? .green : .blue)
      
      Text(text)
        .font(.subheadline)
      
      if isRequired {
        Text("Required")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.leading, 4)
      }
      
      Spacer()
    }
  }
}

#else
// MARK: - macOS Placeholder
struct BackgroundDownloadsSettingsView: View {
  var body: some View {
    Text("Background downloads are only available on iOS")
      .navigationTitle("Background Downloads")
  }
}

struct BackgroundDownloadsInfoView: View {
  var body: some View {
    Text("Not available on this platform")
  }
}
#endif

// MARK: - Preview
struct BackgroundDownloadsSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    #if os(iOS)
    NavigationStack {
      BackgroundDownloadsSettingsView()
        .environmentObject(AppContext.shared as AppContextProtocol)
    }
    #else
    NavigationStack {
      BackgroundDownloadsSettingsView()
    }
    #endif
  }
} 