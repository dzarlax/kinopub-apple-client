//
//  TVChannelsView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.01.2025.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

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
      // Channel Logo
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
      
      // Channel Info
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

// MARK: - ViewModel

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
      errorMessage = error.localizedDescription
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

#Preview {
  TVChannelsView()
    .environmentObject(AppContext.mock())
} 