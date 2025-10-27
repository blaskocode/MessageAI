/**
 * MediaUploadService - Handles image and GIF uploads to Firebase Storage
 * Supports photo library, camera, and drag-and-drop media
 */

import Foundation
import FirebaseStorage
import UIKit
import SwiftUI

@MainActor
class MediaUploadService: ObservableObject {
    static let shared = MediaUploadService()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadError: String?
    
    private let storage = Storage.storage()
    private let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB limit
    
    private init() {}
    
    // MARK: - Upload Methods
    
    func uploadImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(MediaUploadError.invalidImageData))
            return
        }
        
        uploadMedia(
            data: imageData,
            contentType: "image/jpeg",
            conversationId: conversationId,
            messageId: messageId,
            completion: completion
        )
    }
    
    func uploadGIF(
        data: Data,
        conversationId: String,
        messageId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        uploadMedia(
            data: data,
            contentType: "image/gif",
            conversationId: conversationId,
            messageId: messageId,
            completion: completion
        )
    }
    
    func uploadMediaFromURL(
        url: URL,
        conversationId: String,
        messageId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Determine content type from URL
        let contentType = determineContentType(from: url)
        
        do {
            let data = try Data(contentsOf: url)
            uploadMedia(
                data: data,
                contentType: contentType,
                conversationId: conversationId,
                messageId: messageId,
                completion: completion
            )
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Private Methods
    
    private func uploadMedia(
        data: Data,
        contentType: String,
        conversationId: String,
        messageId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Check file size
        guard data.count <= maxFileSize else {
            completion(.failure(MediaUploadError.fileTooLarge))
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil
        
        // Create storage reference
        let fileName = "\(messageId)_\(Int(Date().timeIntervalSince1970))"
        let fileExtension = contentType.contains("gif") ? "gif" : "jpg"
        let storageRef = storage.reference()
            .child("conversations")
            .child(conversationId)
            .child("media")
            .child("\(fileName).\(fileExtension)")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        metadata.cacheControl = "public,max-age=31536000" // 1 year cache
        
        // Upload with progress tracking
        let uploadTask = storageRef.putData(data, metadata: metadata) { [weak self] metadata, error in
            DispatchQueue.main.async {
                self?.isUploading = false
                
                if let error = error {
                    self?.uploadError = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.uploadError = error.localizedDescription
                            completion(.failure(error))
                        } else if let downloadURL = url {
                            completion(.success(downloadURL.absoluteString))
                        } else {
                            completion(.failure(MediaUploadError.noDownloadURL))
                        }
                    }
                }
            }
        }
        
        // Track upload progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let progress = snapshot.progress else { return }
                self?.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            }
        }
    }
    
    private func determineContentType(from url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            return "image/jpeg" // Default fallback
        }
    }
    
    // MARK: - Image Processing
    
    func resizeImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Ensure minimum size
        newSize.width = max(newSize.width, 200)
        newSize.height = max(newSize.height, 200)
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail ?? image
    }
}

// MARK: - Error Types

enum MediaUploadError: LocalizedError {
    case invalidImageData
    case fileTooLarge
    case noDownloadURL
    case uploadCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .fileTooLarge:
            return "File is too large (max 10MB)"
        case .noDownloadURL:
            return "Failed to get download URL"
        case .uploadCancelled:
            return "Upload was cancelled"
        }
    }
}

// MARK: - Media Types

enum MediaContentType: String, CaseIterable {
    case image = "image"
    case gif = "gif"
    
    var fileExtensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "webp"]
        case .gif:
            return ["gif"]
        }
    }
    
    var mimeTypes: [String] {
        switch self {
        case .image:
            return ["image/jpeg", "image/png", "image/webp"]
        case .gif:
            return ["image/gif"]
        }
    }
}
