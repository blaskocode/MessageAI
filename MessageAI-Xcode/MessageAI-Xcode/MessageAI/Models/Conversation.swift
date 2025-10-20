//
//  Conversation.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation
import SwiftData

@Model
class Conversation: Identifiable, Codable {
    
    @Attribute(.unique) var id: String
    var type: ConversationType
    var participantIds: [String]
    var participantDetails: [String: ParticipantInfo]
    var lastMessageText: String?
    var lastMessageSenderId: String?
    var lastMessageTimestamp: Date?
    var lastUpdated: Date
    var createdAt: Date
    
    // Group-specific
    var groupName: String?
    var createdBy: String?
    
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]?
    
    init(
        id: String,
        type: ConversationType,
        participantIds: [String],
        participantDetails: [String: ParticipantInfo] = [:],
        lastMessageText: String? = nil,
        lastMessageSenderId: String? = nil,
        lastMessageTimestamp: Date? = nil,
        lastUpdated: Date = Date(),
        createdAt: Date = Date(),
        groupName: String? = nil,
        createdBy: String? = nil
    ) {
        self.id = id
        self.type = type
        self.participantIds = participantIds
        self.participantDetails = participantDetails
        self.lastMessageText = lastMessageText
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
        self.groupName = groupName
        self.createdBy = createdBy
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id = "conversationId"
        case type, participantIds, participantDetails
        case lastMessageText, lastMessageSenderId, lastMessageTimestamp
        case lastUpdated, createdAt, groupName, createdBy
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(ConversationType.self, forKey: .type)
        self.participantIds = try container.decode([String].self, forKey: .participantIds)
        self.participantDetails = try container.decode([String: ParticipantInfo].self, forKey: .participantDetails)
        self.lastMessageText = try container.decodeIfPresent(String.self, forKey: .lastMessageText)
        self.lastMessageSenderId = try container.decodeIfPresent(String.self, forKey: .lastMessageSenderId)
        self.lastMessageTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastMessageTimestamp)
        self.lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        self.createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(participantIds, forKey: .participantIds)
        try container.encode(participantDetails, forKey: .participantDetails)
        try container.encodeIfPresent(lastMessageText, forKey: .lastMessageText)
        try container.encodeIfPresent(lastMessageSenderId, forKey: .lastMessageSenderId)
        try container.encodeIfPresent(lastMessageTimestamp, forKey: .lastMessageTimestamp)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(groupName, forKey: .groupName)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
    }
}

// MARK: - Supporting Types

enum ConversationType: String, Codable {
    case direct
    case group
}

struct ParticipantInfo: Codable {
    let name: String
    let photoURL: String?
}

