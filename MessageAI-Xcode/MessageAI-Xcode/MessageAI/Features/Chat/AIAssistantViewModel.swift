/**
 * AIAssistantViewModel - Manages AI Assistant conversations
 * PR #8: AI Assistant with RAG
 */

import Foundation
import SwiftUI

// MARK: - Assistant Message Model

struct AssistantMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    let sources: [String] // Message IDs used as context
    
    init(id: String = UUID().uuidString, text: String, isUser: Bool, sources: [String] = []) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.sources = sources
    }
}

// MARK: - ViewModel

@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AssistantMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let aiService = AIService.shared
    let conversationId: String? // Optional - if asking about specific conversation
    
    init(conversationId: String? = nil) {
        self.conversationId = conversationId
        
        // Add welcome message
        let welcomeText = conversationId != nil 
            ? "Hi! I can help you with this conversation. Ask me to summarize it, translate messages, or find specific information."
            : "Hi! I'm your AI assistant. I can help you understand your conversations, translate messages, and answer questions about your message history."
        
        messages.append(AssistantMessage(
            text: welcomeText,
            isUser: false
        ))
    }
    
    // MARK: - Query Assistant
    
    func sendQuery(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = AssistantMessage(text: query, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (response, sources) = try await aiService.queryAIAssistant(
                query: query,
                conversationId: conversationId
            )
            
            // Add assistant response
            let assistantMessage = AssistantMessage(
                text: response,
                isUser: false,
                sources: sources
            )
            messages.append(assistantMessage)
            
        } catch {
            errorMessage = "Failed to get response: \(error.localizedDescription)"
            print("❌ Assistant query failed: \(error)")
            
            // Add error message
            let errorMsg = AssistantMessage(
                text: "I'm sorry, I couldn't process that request. Please try again.",
                isUser: false
            )
            messages.append(errorMsg)
        }
        
        isLoading = false
    }
    
    // MARK: - Summarize Conversation
    
    func summarizeConversation() async {
        guard let conversationId = conversationId else {
            errorMessage = "No conversation to summarize"
            return
        }
        
        // Add user request
        let userMessage = AssistantMessage(text: "Summarize this conversation", isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        errorMessage = nil
        
        do {
            let summary = try await aiService.summarizeConversation(conversationId: conversationId)
            
            // Add summary response
            let summaryMessage = AssistantMessage(
                text: "Here's a summary of your conversation:\n\n\(summary)",
                isUser: false
            )
            messages.append(summaryMessage)
            
        } catch {
            errorMessage = "Failed to generate summary: \(error.localizedDescription)"
            print("❌ Summary failed: \(error)")
            
            let errorMsg = AssistantMessage(
                text: "I'm sorry, I couldn't generate a summary. Please try again.",
                isUser: false
            )
            messages.append(errorMsg)
        }
        
        isLoading = false
    }
    
    // MARK: - Quick Actions
    
    func suggestQuickActions() -> [String] {
        // Get context from last few messages
        let recentMessages = messages.suffix(3)
        
        // If conversation-specific
        if conversationId != nil {
            // Show different suggestions based on conversation
            let hasAskedAboutTranslation = recentMessages.contains { $0.text.lowercased().contains("translate") }
            let hasAskedAboutSummary = recentMessages.contains { $0.text.lowercased().contains("summar") }
            
            var suggestions: [String] = []
            
            if !hasAskedAboutSummary {
                suggestions.append("Summarize this conversation")
            }
            
            suggestions.append(contentsOf: [
                "What did we talk about?",
                "Find messages about...",
                "Any questions I should ask?"
            ])
            
            if !hasAskedAboutTranslation {
                suggestions.append("Translate the last message")
            }
            
            return Array(suggestions.prefix(4))
            
        } else {
            // General assistant
            return [
                "Show my recent conversations",
                "What languages do I use?",
                "Help me translate something",
                "Explain a cultural phrase"
            ]
        }
    }
}

