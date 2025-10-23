//
//  User.swift
//  MessageAI
//
//  Created on October 20, 2025
//

import Foundation

class User: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String
    var profilePictureURL: String?
    var profileColorHex: String
    var initials: String
    var isOnline: Bool
    var lastSeen: Date
    var createdAt: Date
    var fcmToken: String?
    
    // MARK: - AI Features (PR #2)
    var fluentLanguages: [String] // ISO 639-1 language codes (e.g., ["en", "es", "fr"])
    var culturalHintsEnabled: Bool // PR #3: Show cultural context hints

    init(
        id: String,
        email: String,
        displayName: String,
        profilePictureURL: String? = nil,
        profileColorHex: String,
        initials: String,
        isOnline: Bool = false,
        lastSeen: Date = Date(),
        createdAt: Date = Date(),
        fcmToken: String? = nil,
        fluentLanguages: [String] = ["en"], // Default to English
        culturalHintsEnabled: Bool = true
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.profileColorHex = profileColorHex
        self.initials = initials
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
        self.fcmToken = fcmToken
        self.fluentLanguages = fluentLanguages
        self.culturalHintsEnabled = culturalHintsEnabled
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case email, displayName, profilePictureURL
        case profileColorHex, initials, isOnline
        case lastSeen, createdAt, fcmToken
        case fluentLanguages, culturalHintsEnabled
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profilePictureURL = try container.decodeIfPresent(String.self, forKey: .profilePictureURL)
        self.profileColorHex = try container.decode(String.self, forKey: .profileColorHex)
        self.initials = try container.decode(String.self, forKey: .initials)
        self.isOnline = try container.decode(Bool.self, forKey: .isOnline)
        self.lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        // Backward compatibility: default values if not present
        self.fluentLanguages = try container.decodeIfPresent([String].self, forKey: .fluentLanguages) ?? ["en"]
        self.culturalHintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .culturalHintsEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profilePictureURL, forKey: .profilePictureURL)
        try container.encode(profileColorHex, forKey: .profileColorHex)
        try container.encode(initials, forKey: .initials)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(fcmToken, forKey: .fcmToken)
        try container.encode(fluentLanguages, forKey: .fluentLanguages)
        try container.encode(culturalHintsEnabled, forKey: .culturalHintsEnabled)
    }
}
