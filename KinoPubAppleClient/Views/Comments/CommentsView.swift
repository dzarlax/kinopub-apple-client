//
//  CommentsView.swift
//  KinoPubAppleClient
//
//  Created by Assistant on 2023.
//

import SwiftUI
import KinoPubBackend

struct CommentsView: View {
  let mediaId: Int
  let videoId: Int?
  let seasonId: Int?
  
  @StateObject private var viewModel = CommentsViewModel()
  @EnvironmentObject var appContext: AppContext
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack {
        if viewModel.comments.isEmpty && !viewModel.isLoading {
          ContentUnavailableView(
            "Нет комментариев",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Пока никто не оставил комментарии к этому контенту")
          )
        } else {
          List(viewModel.comments) { comment in
            CommentCard(comment: comment)
          }
          .refreshable {
            await viewModel.loadComments(
              mediaId: mediaId,
              videoId: videoId,
              seasonId: seasonId,
              contentService: appContext.contentService
            )
          }
        }
      }
      .navigationTitle("Комментарии")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Готово") {
            dismiss()
          }
        }
      }
      .task {
        await viewModel.loadComments(
          mediaId: mediaId,
          videoId: videoId,
          seasonId: seasonId,
          contentService: appContext.contentService
        )
      }
    }
  }
}

struct CommentCard: View {
  let comment: Comment
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Comment Header
      HStack {
        // Avatar
        AsyncImage(url: URL(string: comment.avatar ?? "")) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Circle()
            .fill(Color.blue.opacity(0.3))
            .overlay(
              Text(String(comment.author.prefix(1).uppercased()))
                .font(.caption.bold())
                .foregroundColor(.blue)
            )
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(comment.author)
              .font(.subheadline.bold())
            
            if let rating = comment.rating {
              HStack(spacing: 2) {
                Image(systemName: "star.fill")
                  .foregroundColor(.yellow)
                  .font(.caption)
                Text("\(rating)/10")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
          
          Text(formatDate(comment.date))
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Spacer()
      }
      
      // Comment Text
      Text(comment.message)
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
      
      // Like/Dislike
      HStack {
        HStack(spacing: 4) {
          Image(systemName: "hand.thumbsup")
            .foregroundColor(.green)
          Text("\(comment.likes)")
            .font(.caption)
        }
        
        HStack(spacing: 4) {
          Image(systemName: "hand.thumbsdown")
            .foregroundColor(.red)
          Text("\(comment.dislikes)")
            .font(.caption)
        }
        
        Spacer()
      }
      .foregroundColor(.secondary)
      
      // Replies
      if let replies = comment.replies, !replies.isEmpty {
        Divider()
        
        VStack(alignment: .leading, spacing: 8) {
          Text("Ответы:")
            .font(.caption.bold())
            .foregroundColor(.secondary)
          
          ForEach(replies) { reply in
            CommentReplyCard(reply: reply)
          }
        }
        .padding(.leading, 16)
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
  
  private func formatDate(_ dateString: String) -> String {
    // Simple date formatting - can be improved with proper DateFormatter
    return dateString
  }
}

struct CommentReplyCard: View {
  let reply: Comment
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(reply.author)
          .font(.caption.bold())
        
        Text(formatDate(reply.date))
          .font(.caption2)
          .foregroundColor(.secondary)
        
        Spacer()
      }
      
      Text(reply.message)
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .background(Color(.systemGray6))
    .cornerRadius(8)
  }
  
  private func formatDate(_ dateString: String) -> String {
    return dateString
  }
}

// MARK: - ViewModel

@MainActor
class CommentsViewModel: ObservableObject {
  @Published var comments: [Comment] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  func loadComments(
    mediaId: Int,
    videoId: Int?,
    seasonId: Int?,
    contentService: VideoContentService
  ) async {
    guard !isLoading else { return }
    
    isLoading = true
    
    do {
      let response = try await contentService.fetchComments(
        for: mediaId,
        video: videoId,
        season: seasonId
      )
      comments = response.items
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
    
    isLoading = false
  }
  
  func refresh() async {
    comments.removeAll()
    // Will reload in next frame
  }
}

#Preview {
  CommentsView(mediaId: 123, videoId: nil, seasonId: nil)
    .environmentObject(AppContext.mock())
} 