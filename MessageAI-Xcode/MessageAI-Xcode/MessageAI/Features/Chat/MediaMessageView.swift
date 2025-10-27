/**
 * MediaMessageView - Displays images and GIFs in message bubbles
 * Supports tap to view full screen, loading states, and error handling
 */

import SwiftUI

struct MediaMessageView: View {
    let mediaURL: String
    let mediaType: MediaType
    let isFromCurrentUser: Bool
    
    @State private var isLoading = true
    @State private var hasError = false
    @State private var showFullScreen = false
    @State private var imageSize: CGSize = .zero
    @State private var imageAnalysis: ImageAnalysis?
    @State private var showAnalysis = false
    @State private var retryCount = 0
    @State private var loadingKey = UUID()
    
    private let maxWidth: CGFloat = 250
    private let maxHeight: CGFloat = 300
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media Content
            Group {
                if hasError {
                    MediaErrorView(mediaType: mediaType)
                } else {
                    MediaContentView(
                        mediaURL: mediaURL,
                        mediaType: mediaType,
                        isLoading: $isLoading,
                        hasError: $hasError,
                        onTap: { showFullScreen = true },
                        loadingKey: loadingKey
                    )
                }
            }
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFromCurrentUser ? 
                        Color.messagePrimary.opacity(0.3) : 
                        Color(.systemGray4), 
                        lineWidth: 1
                    )
            )
            .clipped()
            
            // Loading indicator
            if isLoading && !hasError {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Retry button for failed loads
            if hasError {
                Button(action: retryLoad) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Retry")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // AI Analysis Button (for images only)
            if mediaType == .image && !isFromCurrentUser {
                HStack {
                    Button(action: analyzeImage) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.caption)
                            Text("Analyze Image")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .disabled(isLoading)
                    
                    Spacer()
                }
            }
            
            // AI Analysis Results
            if let analysis = imageAnalysis, showAnalysis {
                ImageAnalysisView(analysis: analysis)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenMediaView(
                mediaURL: mediaURL,
                mediaType: mediaType,
                isPresented: $showFullScreen
            )
        }
        .accessibilitySupport(
            label: "\(mediaType.displayName) message",
            hint: "Double tap to view full screen",
            traits: .isButton
        )
    }
    
    // MARK: - Private Methods
    
    private func retryLoad() {
        hasError = false
        isLoading = true
        loadingKey = UUID() // Force AsyncImage to reload
        retryCount += 1
        print("🔄 Retrying image load (attempt \(retryCount)) for: \(mediaURL)")
    }
    
    private func analyzeImage() {
        Task {
            // Load image from URL
            guard let url = URL(string: mediaURL),
                  let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) else {
                return
            }
            
            // Analyze image
            AIImageAnalysisService.shared.analyzeImage(image) { result in
                switch result {
                case .success(let analysis):
                    imageAnalysis = analysis
                    showAnalysis = true
                case .failure(let error):
                    print("❌ Image analysis failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Media Content View

struct MediaContentView: View {
    let mediaURL: String
    let mediaType: MediaType
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    let onTap: () -> Void
    var loadingKey: UUID
    
    var body: some View {
        Group {
            switch mediaType {
            case .image:
                AsyncImage(url: URL(string: mediaURL)) { phase in
                    switch phase {
                    case .empty:
                        ImagePlaceholderView()
                            .onAppear {
                                print("📸 Loading image from: \(mediaURL)")
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onTapGesture { onTap() }
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                    hasError = false
                                    print("✅ Image loaded successfully from: \(mediaURL)")
                                }
                            }
                    case .failure(let error):
                        ImagePlaceholderView()
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                    hasError = true
                                    print("❌ Failed to load image: \(error.localizedDescription)")
                                    print("URL: \(mediaURL)")
                                }
                            }
                    @unknown default:
                        ImagePlaceholderView()
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                }
                            }
                    }
                }
                .id(loadingKey) // Force reload when key changes
                
            case .gif:
                AsyncImage(url: URL(string: mediaURL)) { phase in
                    switch phase {
                    case .empty:
                        ImagePlaceholderView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onTapGesture { onTap() }
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                    hasError = false
                                }
                            }
                    case .failure:
                        ImagePlaceholderView()
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                    hasError = true
                                }
                            }
                    @unknown default:
                        ImagePlaceholderView()
                            .onAppear {
                                DispatchQueue.main.async {
                                    isLoading = false
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ImagePlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

struct MediaErrorView: View {
    let mediaType: MediaType
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mediaType.iconName)
                .font(.system(size: 32))
                .foregroundColor(.red)
            Text("Failed to load \(mediaType.displayName.lowercased())")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

// MARK: - Full Screen Media View

struct FullScreenMediaView: View {
    let mediaURL: String
    let mediaType: MediaType
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Group {
                    switch mediaType {
                    case .image:
                        AsyncImage(url: URL(string: mediaURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = value
                                            }
                                            .onEnded { value in
                                                withAnimation(.spring()) {
                                                    if scale < 1.0 {
                                                        scale = 1.0
                                                    } else if scale > 3.0 {
                                                        scale = 3.0
                                                    }
                                                }
                                            }
                                    )
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                offset = value.translation
                                            }
                                            .onEnded { _ in
                                                withAnimation(.spring()) {
                                                    offset = .zero
                                                }
                                            }
                                    )
                            case .failure(_):
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)
                                    Text("Failed to load image")
                                        .foregroundColor(.white)
                                }
                            @unknown default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        
                    case .gif:
                        AsyncImage(url: URL(string: mediaURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = value
                                            }
                                            .onEnded { value in
                                                withAnimation(.spring()) {
                                                    if scale < 1.0 {
                                                        scale = 1.0
                                                    } else if scale > 3.0 {
                                                        scale = 3.0
                                                    }
                                                }
                                            }
                                    )
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                offset = value.translation
                                            }
                                            .onEnded { _ in
                                                withAnimation(.spring()) {
                                                    offset = .zero
                                                }
                                            }
                                    )
                            case .failure(_):
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)
                                    Text("Failed to load GIF")
                                        .foregroundColor(.white)
                                }
                            @unknown default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Add share functionality
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MediaMessageView(
            mediaURL: "https://picsum.photos/300/200",
            mediaType: .image,
            isFromCurrentUser: false
        )
        
        MediaMessageView(
            mediaURL: "https://media.giphy.com/media/3o7TKSjRrfIPjeiVy/giphy.gif",
            mediaType: .gif,
            isFromCurrentUser: true
        )
    }
    .padding()
}
