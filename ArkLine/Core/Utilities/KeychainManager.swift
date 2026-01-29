import Foundation
import Security

// MARK: - Keychain Error
enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case dataConversionFailed
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .dataConversionFailed:
            return "Failed to convert data"
        case .itemNotFound:
            return "Item not found in Keychain"
        }
    }
}

// MARK: - Keychain Manager
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.arkline.app"

    private init() {}

    // MARK: - Data Operations

    /// Save data to Keychain
    func save(_ data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load data from Keychain
    func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.dataConversionFailed
        }

        return data
    }

    /// Load data from Keychain, returning nil if not found
    func loadOptional(forKey key: String) -> Data? {
        try? load(forKey: key)
    }

    /// Delete data from Keychain
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if a key exists in Keychain
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - String Convenience Methods

    /// Save a string to Keychain
    func saveString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try save(data, forKey: key)
    }

    /// Load a string from Keychain
    func loadString(forKey key: String) throws -> String {
        let data = try load(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    /// Load a string from Keychain, returning nil if not found
    func loadStringOptional(forKey key: String) -> String? {
        try? loadString(forKey: key)
    }

    // MARK: - Bool Convenience Methods

    /// Save a boolean to Keychain
    func saveBool(_ value: Bool, forKey key: String) throws {
        let data = Data([value ? 1 : 0])
        try save(data, forKey: key)
    }

    /// Load a boolean from Keychain
    func loadBool(forKey key: String) -> Bool {
        guard let data = try? load(forKey: key),
              let byte = data.first else {
            return false
        }
        return byte == 1
    }

    // MARK: - Date Convenience Methods

    /// Save a date to Keychain
    func saveDate(_ date: Date, forKey key: String) throws {
        let timestamp = date.timeIntervalSince1970
        var value = timestamp
        let data = Data(bytes: &value, count: MemoryLayout<TimeInterval>.size)
        try save(data, forKey: key)
    }

    /// Load a date from Keychain
    func loadDate(forKey key: String) -> Date? {
        guard let data = try? load(forKey: key),
              data.count == MemoryLayout<TimeInterval>.size else {
            return nil
        }
        let timestamp = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Clear All

    /// Clear all Keychain items for this app
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Keys
extension KeychainManager {
    enum Keys {
        static let passcodeHash = "arkline.passcodeHash"
        static let passcodeSalt = "arkline.passcodeSalt"
        static let lockoutEndTime = "arkline.lockoutEndTime"
        static let failedAttempts = "arkline.failedAttempts"
        static let biometricEnabled = "arkline.biometricEnabled"
        static let accessToken = "arkline.accessToken"
        static let refreshToken = "arkline.refreshToken"
    }
}
