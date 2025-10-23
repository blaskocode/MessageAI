//
//  Message.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import SwiftData

@Model
class Message: Identifiable, Codable {

    @Attribute(.unique) var id: String
    var senderId: String
    var text: String?
    var mediaURL: String?
    var mediaType: MediaType?
    var timestamp: Date
    var status: MessageStatus
    var deliveredTo: [String]
    var readBy: [String]
    
    // AI Features (PR #2)
    var detectedLanguage: String? // ISO 639-1 language code (e.g., "en", "es", "fr")

    // For optimistic updates - temporary ID before server confirmation
    var temporaryId: String?
    var isPending: Bool

    var conversation: Conversation?

    init(
        id: String,
        senderId: String,
        text: String? = nil,
        mediaURL: String? = nil,
        mediaType: MediaType? = nil,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        deliveredTo: [String] = [],
        readBy: [String] = [],
        detectedLanguage: String? = nil,
        temporaryId: String? = nil,
        isPending: Bool = false
    ) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.timestamp = timestamp
        self.status = status
        self.deliveredTo = deliveredTo
        self.readBy = readBy
        self.detectedLanguage = detectedLanguage
        self.temporaryId = temporaryId
        self.isPending = isPending
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id = "messageId"
        case senderId, text, mediaURL, mediaType
        case timestamp, status, deliveredTo, readBy
        case detectedLanguage
        case temporaryId, isPending
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.senderId = try container.decode(String.self, forKey: .senderId)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL)
        self.mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.status = try container.decode(MessageStatus.self, forKey: .status)
        self.deliveredTo = try container.decode([String].self, forKey: .deliveredTo)
        self.readBy = try container.decode([String].self, forKey: .readBy)
        self.detectedLanguage = try container.decodeIfPresent(String.self, forKey: .detectedLanguage)
        self.temporaryId = try container.decodeIfPresent(String.self, forKey: .temporaryId)
        self.isPending = try container.decode(Bool.self, forKey: .isPending)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(senderId, forKey: .senderId)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(mediaURL, forKey: .mediaURL)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(status, forKey: .status)
        try container.encode(deliveredTo, forKey: .deliveredTo)
        try container.encode(readBy, forKey: .readBy)
        try container.encodeIfPresent(detectedLanguage, forKey: .detectedLanguage)
        try container.encodeIfPresent(temporaryId, forKey: .temporaryId)
        try container.encode(isPending, forKey: .isPending)
    }
}

// MARK: - Supporting Types

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum MediaType: String, Codable {
    case image
    case gif
}
