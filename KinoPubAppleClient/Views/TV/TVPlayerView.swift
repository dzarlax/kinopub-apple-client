//
//  TVPlayerView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.01.2025.
//

import SwiftUI
import AVKit
import KinoPubBackend
import KinoPubUI

struct TVPlayerView: View {
  let channel: TVChannel
  @State private var player: AVPlayer
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var navigationState: NavigationState
  @State private var hideNavigationBar = false
  @State private var isPlaying = false
  
  init(channel: TVChannel) {
    self.channel = channel
    self._player = State(initialValue: AVPlayer(url: URL(string: channel.stream)!))
  }
  
  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .top) {
        videoPlayer
        backButton
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
#if os(macOS)
    .toolbar(.hidden, for: .windowToolbar)
#endif
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
  
  var videoPlayer: some View {
    VideoPlayer(player: player)
      .onAppear(perform: {
        player.play()
        // Observe playback state
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { _ in
          isPlaying = player.rate > 0
        }
      })
      .onDisappear(perform: {
        player.pause()
      })
  }
  
  var backButton: some View {
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
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      .padding(.leading, 20)
      .padding(.top, 20)
      
      Spacer()
      
      // Channel info
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
  

}

#Preview {
  TVPlayerView(channel: TVChannel(
    id: 1,
    name: "test",
    title: "Test Channel",
    logos: TVChannelLogos(s: "", m: ""),
    stream: "https://test.com/stream.m3u8",
    embed: "",
    current: "",
    playlist: "",
    status: nil
  ))
  .environmentObject(NavigationState())
} 