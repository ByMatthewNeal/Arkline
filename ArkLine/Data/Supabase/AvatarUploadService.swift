import Foundation
import UIKit

// MARK: - Avatar Upload Service
/// Handles uploading and managing user avatar images in Supabase Storage.
actor AvatarUploadService {
    // MARK: - Singleton
    static let shared = AvatarUploadService()

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    // MARK: - Private Init
    private init() {}

    // MARK: - Upload Avatar

    /// Upload avatar image and return public URL
    /// - Parameters:
    ///   - data: Image data (JPEG format recommended)
    ///   - userId: User's UUID
    /// - Returns: Public URL to the uploaded avatar
    func uploadAvatar(data: Data, for userId: UUID) async throws -> URL {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        // Resize to max 512x512 to save bandwidth
        let uploadData = Self.resizeImage(data: data, maxDimension: 512)

        let fileName = "\(userId.uuidString)/avatar_\(Int(Date().timeIntervalSince1970)).jpg"
        _ = try await supabase.storage
            .from(SupabaseBucket.avatars.rawValue)
            .upload(
                fileName,
                data: uploadData,
                options: .init(contentType: "image/jpeg", upsert: true)
            )

        let publicURL = try supabase.storage
            .from(SupabaseBucket.avatars.rawValue)
            .getPublicURL(path: fileName)

        logInfo("Uploaded avatar for user \(userId): \(publicURL)", category: .data)
        return publicURL
    }

    // MARK: - Delete Avatar

    /// Delete an avatar from storage
    /// - Parameter url: The public URL of the avatar to delete
    func deleteAvatar(at url: URL) async throws {
        guard supabase.isConfigured else {
            return
        }

        // Extract path from URL (everything after /avatars/)
        let urlString = url.absoluteString
        guard let range = urlString.range(of: "/avatars/") else {
            logWarning("Could not extract avatar path from URL: \(url)", category: .data)
            return
        }
        let path = String(urlString[range.upperBound...])

        guard !path.isEmpty else {
            return
        }

        try await supabase.storage
            .from(SupabaseBucket.avatars.rawValue)
            .remove(paths: [path])

        logInfo("Deleted avatar at: \(url)", category: .data)
    }

    // MARK: - Image Resize

    /// Resizes image data to fit within maxDimension, returns JPEG data
    static func resizeImage(data: Data, maxDimension: CGFloat, compressionQuality: CGFloat = 0.8) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            // Already small enough, just ensure JPEG
            return image.jpegData(compressionQuality: compressionQuality) ?? data
        }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality) ?? data
    }
}
