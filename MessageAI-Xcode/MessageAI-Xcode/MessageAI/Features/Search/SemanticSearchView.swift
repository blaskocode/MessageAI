/**
 * SemanticSearchView - Search messages by meaning, not just keywords
 * PR #6: Message Embeddings & Semantic Search
 */

import SwiftUI

struct SemanticSearchView: View {
    @StateObject private var viewModel = SemanticSearchViewModel()
    @Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search by meaning...", text: $viewModel.searchQuery)
                            .focused($isSearchFocused)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .onSubmit {
                                Task {
                                    await viewModel.search()
                                }
                            }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.searchQuery = ""
                                viewModel.results = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Button {
                        Task {
                            await viewModel.search()
                        }
                    } label: {
                        Text("Search")
                            .fontWeight(.semibold)
                    }
                    .disabled(viewModel.searchQuery.isEmpty || viewModel.isSearching)
                }
                .padding()
                
                // Search Scope Toggle
                Picker("Scope", selection: $viewModel.searchScope) {
                    Text("All Messages").tag(SearchScope.all)
                    Text("This Conversation").tag(SearchScope.current)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(viewModel.conversationId == nil)
                
                Divider()
                    .padding(.top, 8)
                
                // Results
                if viewModel.isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Searching by meaning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.searchQuery.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.opacity(0.3))
                        
                        Text("Semantic Search")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Find messages by meaning, not just keywords")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ExampleRow(query: "celebration", finds: "Happy birthday! 🎉")
                            ExampleRow(query: "meeting time", finds: "Let's meet at 3pm")
                            ExampleRow(query: "feeling sick", finds: "I have a cold")
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty && !viewModel.isSearching {
                    // No Results
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("No matches found")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            Text("Try different words or phrases")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Results List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.results) { result in
                                SearchResultRow(
                                    result: result,
                                    onTap: {
                                        // TODO: Navigate to conversation with message
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct ExampleRow: View {
    let query: String
    let finds: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\"\(query)\"")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("→ \(finds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(result.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Similarity Badge
                    Text("\(Int(result.similarity * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(similarityColor(result.similarity))
                        .clipShape(Capsule())
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption2)
                    Text("Conversation")
                        .font(.caption)
                    
                    // Only show language if it's detected (not "unknown")
                    if !result.language.isEmpty && result.language.lowercased() != "unknown" {
                        Text("•")
                            .font(.caption2)
                        Text(languageName(result.language))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private func similarityColor(_ similarity: Double) -> Color {
        if similarity >= 0.8 {
            return .green
        } else if similarity >= 0.6 {
            return .blue
        } else {
            return .orange
        }
    }
    
    private func languageName(_ code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
}

enum SearchScope {
    case all
    case current
}

@MainActor
class SemanticSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var searchScope: SearchScope = .all
    @Published var errorMessage: String?
    
    var conversationId: String?
    private let aiService = AIService.shared
    
    func search() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        
        let queryToSearch = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversationFilter = searchScope == .current ? conversationId : nil
        
        do {
            let searchResults = try await aiService.semanticSearch(
                query: queryToSearch,
                conversationId: conversationFilter,
                limit: 20
            )
            
            results = searchResults
            
            if searchResults.isEmpty {
                print("⚠️ No embeddings found. Messages need embeddings to be searchable.")
                errorMessage = "No embeddings exist yet. Send new messages to test search."
            } else {
                print("✅ Found \(searchResults.count) results for \"\(queryToSearch)\"")
            }
        } catch {
            print("❌ Semantic search failed: \(error.localizedDescription)")
            errorMessage = "Search failed: \(error.localizedDescription)"
            results = []
        }
    }
}

#Preview {
    SemanticSearchView()
}

