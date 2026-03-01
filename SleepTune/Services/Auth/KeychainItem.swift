import Foundation

struct KeychainItem {
    enum KeychainError: Error {
        case noItem
        case unexpectedData
        case unhandledError(OSStatus)
    }

    let service: String
    let account: String

    func readItem() throws -> String {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        guard status != errSecItemNotFound else { throw KeychainError.noItem }
        guard status == noErr else { throw KeychainError.unhandledError(status) }

        guard
            let item = result as? [String: AnyObject],
            let data = item[kSecValueData as String] as? Data,
            let string = String(data: data, encoding: .utf8)
        else { throw KeychainError.unexpectedData }

        return string
    }

    func saveItem(_ value: String) throws {
        let data = value.data(using: .utf8)!

        if (try? readItem()) != nil {
            var attrs = [String: AnyObject]()
            attrs[kSecValueData as String] = data as AnyObject
            let status = SecItemUpdate(baseQuery() as CFDictionary, attrs as CFDictionary)
            guard status == noErr else { throw KeychainError.unhandledError(status) }
        } else {
            var newItem = baseQuery()
            newItem[kSecValueData as String] = data as AnyObject
            let status = SecItemAdd(newItem as CFDictionary, nil)
            guard status == noErr else { throw KeychainError.unhandledError(status) }
        }
    }

    func deleteItem() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == noErr || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    private func baseQuery() -> [String: AnyObject] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject
        ]
    }

    // MARK: - Convenience

    static var currentUserID: String? {
        try? KeychainItem(service: "com.sleep-tune.app", account: "userID").readItem()
    }
}
