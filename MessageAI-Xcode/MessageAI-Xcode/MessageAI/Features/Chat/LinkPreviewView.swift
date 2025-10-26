/**
 * LinkPreviewView - Rich media previews for URLs in messages
 * Automatically detects URLs and fetches metadata for previews
 */

import SwiftUI

struct LinkPreviewView: View {
    let url: String
    @State private var preview: LinkPreview?
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let preview = preview {
                LinkPreviewCard(preview: preview, url: url)
            } else if isLoading {
                LinkPreviewLoadingView()
            } else if hasError {
                LinkPreviewErrorView(url: url)
            }
        }
        .onAppear {
            Task {
                await loadPreview()
            }
        }
    }
    
    init(url: String) {
        self.url = url
        self._preview = State(initialValue: nil)
        self._isLoading = State(initialValue: false)
        self._hasError = State(initialValue: false)
    }
    
    private func loadPreview() async {
        isLoading = true
        hasError = false
        
        do {
            let preview = try await LinkPreviewService.shared.fetchPreview(for: url)
            await MainActor.run {
                self.preview = preview
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
}

struct LinkPreviewCard: View {
    let preview: LinkPreview
    let url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = preview.imageURL {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    case .failure, .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                    @unknown default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = preview.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }
                
                if let description = preview.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                HStack {
                    if let faviconURL = preview.faviconURL {
                        AsyncImage(url: URL(string: faviconURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            case .failure, .empty:
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            @unknown default:
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(preview.domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .onTapGesture {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }
        .accessibilitySupport(
            label: "Link preview for \(preview.title ?? preview.domain)",
            hint: "Double tap to open link"
        )
    }
}

struct LinkPreviewLoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading preview...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct LinkPreviewErrorView: View {
    let url: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("Preview unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }
        .accessibilitySupport(
            label: "Link preview unavailable",
            hint: "Double tap to open link"
        )
    }
}

// MARK: - Link Preview Models

class LinkPreview: Codable {
    let title: String?
    let description: String?
    let imageURL: String?
    let faviconURL: String?
    let domain: String
    let url: String
    
    init(title: String?, description: String?, imageURL: String?, faviconURL: String?, domain: String, url: String) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.faviconURL = faviconURL
        self.domain = domain
        self.url = url
    }
}

// MARK: - Link Preview Service

class LinkPreviewService {
    static let shared = LinkPreviewService()
    
    private let cache = NSCache<NSString, LinkPreview>()
    private let session = URLSession.shared
    
    private init() {
        cache.countLimit = 100
    }
    
    func fetchPreview(for urlString: String) async throws -> LinkPreview {
        // Check cache first
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached
        }
        
        guard let url = URL(string: urlString) else {
            throw LinkPreviewError.invalidURL
        }
        
        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinkPreviewError.invalidResponse
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LinkPreviewError.invalidHTML
        }
        
        let preview = try parseHTML(html, url: urlString)
        
        // Cache the result
        cache.setObject(preview, forKey: urlString as NSString)
        
        return preview
    }
    
    private func parseHTML(_ html: String, url: String) throws -> LinkPreview {
        let domain = URL(string: url)?.host ?? "Unknown"
        
        // Extract title
        let title = extractMetaContent(from: html, property: "og:title") ??
                   extractMetaContent(from: html, name: "title") ??
                   extractTitleTag(from: html)
        
        // Extract description
        let description = extractMetaContent(from: html, property: "og:description") ??
                         extractMetaContent(from: html, name: "description")
        
        // Extract image
        let imageURL = extractMetaContent(from: html, property: "og:image") ??
                      extractMetaContent(from: html, name: "image")
        
        // Extract favicon
        let faviconURL = extractFavicon(from: html, baseURL: url)
        
        return LinkPreview(
            title: title,
            description: description,
            imageURL: imageURL,
            faviconURL: faviconURL,
            domain: domain,
            url: url
        )
    }
    
    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = #"<meta\s+property=["']\#(property)["']\s+content=["']([^"']+)["']"#
        return extractFirstMatch(from: html, pattern: pattern)
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = #"<meta\s+name=["']\#(name)["']\s+content=["']([^"']+)["']"#
        return extractFirstMatch(from: html, pattern: pattern)
    }
    
    private func extractTitleTag(from html: String) -> String? {
        let pattern = #"<title>([^<]+)</title>"#
        return extractFirstMatch(from: html, pattern: pattern)
    }
    
    private func extractFavicon(from html: String, baseURL: String) -> String? {
        let pattern = #"<link[^>]*rel=["'](?:shortcut\s+)?icon["'][^>]*href=["']([^"']+)["']"#
        if let faviconPath = extractFirstMatch(from: html, pattern: pattern) {
            if faviconPath.hasPrefix("http") {
                return faviconPath
            } else if faviconPath.hasPrefix("//") {
                return "https:" + faviconPath
            } else if faviconPath.hasPrefix("/") {
                return URL(string: baseURL)?.scheme ?? "https" + "://" + (URL(string: baseURL)?.host ?? "") + faviconPath
            } else {
                return URL(string: baseURL)?.deletingLastPathComponent().appendingPathComponent(faviconPath).absoluteString
            }
        }
        return nil
    }
    
    private func extractFirstMatch(from html: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: html.utf16.count)
        
        if let match = regex?.firstMatch(in: html, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: html) {
            return String(html[matchRange])
        }
        
        return nil
    }
}

enum LinkPreviewError: Error {
    case invalidURL
    case invalidResponse
    case invalidHTML
    case parsingFailed
}

#Preview {
    LinkPreviewView(url: "https://www.apple.com")
}
