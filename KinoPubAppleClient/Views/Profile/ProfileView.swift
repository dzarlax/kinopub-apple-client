//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubBackend
import KinoPubKit
import SkeletonUI

struct ProfileView: View {
  
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: ProfileModel
  @AppStorage("selectedLanguage") private var selectedLanguage: String = (Locale.current.language.languageCode?.identifier ?? "en")

  @State private var showLogoutAlert: Bool = false
    
  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color.KinoPub.background.edgesIgnoringSafeArea(.all)
        VStack(alignment: .leading) {
          Form {
            Section {
              LabeledContent("User Name", value: model.userData.username)
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("User Subscription", value: "\(model.userData.subscription.days) \("days".localized)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("Registration Date", value: "\(model.userData.registrationDateFormatted)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("App version", value: Bundle.main.appVersionLong)
            }
              
            languageSection
            
            #if os(iOS)
            Section {
              NavigationLink(destination: BackgroundDownloadsSettingsView_Internal()) {
                HStack {
                  Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                  Text("Background Downloads")
                }
              }
            } header: {
              Text("Downloads")
            }
            #endif
              
            Section {
              Button(action: {
                showLogoutAlert = true
              }, label: {
                Text("Logout").foregroundStyle(Color.red)
              })
              .skeleton(enabled: model.userData.skeleton ?? false)
#if os(macOS)
              .buttonStyle(PlainButtonStyle())
#endif
            }
          }
          .scrollContentBackground(.hidden)
          .background(Color.KinoPub.background)
        }
      }
      .navigationTitle("Profile")
      .onAppear(perform: {
        model.fetch()
      })
      .alert("Are you sure?", isPresented: $showLogoutAlert) {
        Button("Logout", role: .destructive) { model.logout() }
        Button("Cancel", role: .cancel) { }
      }
      .alert("Restarting the app", isPresented: $model.shouldShowExitAlert) {
        Button("OK") {
          exit(0)
        }
        Button("Cancel", role: .cancel) { }
      } message: {
        Text("The app will restart to apply the language change.")
      }
    }
  }
    private var languageSection: some View {
        Section(header: Text("Language")) {
            Picker("Select Language", selection: $selectedLanguage) {
                ForEach(model.availableLanguages.keys.sorted(), id: \.self) { key in
                    Text(model.availableLanguages[key] ?? key).tag(key)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedLanguage) { _, newValue in
                model.changeLanguage(to: newValue)
            }
        }
    }
}

#if os(iOS)
// Временная структура для настроек фоновых загрузок
struct BackgroundDownloadsSettingsView_Internal: View {
  @Environment(\.appContext) var appContext
  @State private var isBackgroundDownloadsEnabled = false
  @State private var notificationPermissionGranted = false
  @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .restricted
  @State private var isTogglingBackgroundDownloads = false
  
  var body: some View {
    List {
      Section {
        Toggle("Background Downloads", isOn: $isBackgroundDownloadsEnabled)
          .disabled(isTogglingBackgroundDownloads)
          .onChange(of: isBackgroundDownloadsEnabled) { _, newValue in
            handleBackgroundDownloadsToggle(newValue)
          }
        
        if isBackgroundDownloadsEnabled {
          HStack {
            Label("Background Refresh", systemImage: backgroundRefreshIconName)
            Spacer()
            Text(backgroundRefreshStatusText)
              .foregroundColor(backgroundRefreshColor)
          }
          
          HStack {
            Label("Task Type", systemImage: "timer")
            Spacer()
            if appContext.backgroundTaskManager != nil {
              Text("BGContinuedProcessingTask")
                .foregroundColor(.green)
            }
          }
          
          // Live Activities временно отключены
          // HStack {
          //   Label("Live Activity", systemImage: "sparkles")
          //   Spacer()
          //   if #available(iOS 26.0, *) {
          //     if let liveActivityManager = appContext.liveActivityManager {
          //       VStack(alignment: .trailing, spacing: 2) {
          //         Text("Enabled")
          //           .foregroundColor(.green)
          //         if liveActivityManager.activeActivityCount > 0 {
          //           Text("\(liveActivityManager.activeActivityCount) active")
          //             .font(.caption2)
          //             .foregroundColor(.blue)
          //         }
          //       }
          //     } else {
          //       Text("Unavailable")
          //         .foregroundColor(.orange)
          //     }
          //   } else {
          //     Text("iOS 26+ Required")
          //       .foregroundColor(.orange)
          //   }
          // }
          
          HStack {
            Label("Active Downloads", systemImage: "arrow.down")
            Spacer()
            Text("\(appContext.downloadManager.activeDownloads.count)")
              .font(.headline)
              .foregroundColor(.blue)
          }
        }
        
      } header: {
        Text("Background Downloads")
      } footer: {
        // Временно отключены Live Activities
        Text("Download videos in the background when the app is not active. BGContinuedProcessingTask provides extended background processing time. Requires Background App Refresh to be enabled.")
      }
    }
    .animation(nil, value: isBackgroundDownloadsEnabled) // Отключаем автоматические анимации для iOS 26 beta
    .navigationTitle("Background Downloads")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      checkCurrentSettings()
    }
  }
  
  private func checkCurrentSettings() {
    isBackgroundDownloadsEnabled = appContext.isBackgroundDownloadsEnabled
    backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
  }
  
  private var backgroundRefreshIconName: String {
    switch backgroundRefreshStatus {
    case .available: return "checkmark.circle.fill"
    case .denied: return "xmark.circle.fill" 
    case .restricted: return "exclamationmark.triangle.fill"
    @unknown default: return "questionmark.circle"
    }
  }
  
  private var backgroundRefreshColor: Color {
    switch backgroundRefreshStatus {
    case .available: return .green
    case .denied: return .red
    case .restricted: return .orange
    @unknown default: return .gray
    }
  }
  
  private var backgroundRefreshStatusText: String {
    switch backgroundRefreshStatus {
    case .available: return "Enabled"
    case .denied: return "Disabled"
    case .restricted: return "Restricted"
    @unknown default: return "Unknown"
    }
  }
  
  private func handleBackgroundDownloadsToggle(_ newValue: Bool) {
    guard !isTogglingBackgroundDownloads else { return }
    
    isTogglingBackgroundDownloads = true
    
    // Используем DispatchQueue вместо Task для избежания проблем с batch updates
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      Task {
        if newValue {
          let success = await appContext.enableBackgroundDownloads()
          await MainActor.run {
            // Обновляем состояние только если оно действительно изменилось
            if self.isBackgroundDownloadsEnabled != success {
              self.isBackgroundDownloadsEnabled = success
            }
            self.isTogglingBackgroundDownloads = false
          }
        } else {
          await MainActor.run {
            self.isBackgroundDownloadsEnabled = false
            self.isTogglingBackgroundDownloads = false
          }
        }
      }
    }
  }
}
#endif

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView(model: ProfileModel(userService: UserServiceMock(),
                                    errorHandler: ErrorHandler(),
                                    authState: AuthState(authService: AuthorizationServiceMock(),
                                                         accessTokenService: AccessTokenServiceMock())))
  }
}
