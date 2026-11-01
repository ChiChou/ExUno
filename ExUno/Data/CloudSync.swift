import Foundation

/// Mirrors progress to iCloud key-value storage (same Apple ID, all devices).
/// Each language is one compressed value; merges are done by `PackProgress.merged`.
/// Limits: 1 MB per key and per app, which holds tens of thousands of reviewed cards.
final class CloudSync {
    private let store = NSUbiquitousKeyValueStore.default
    var onRemoteChange: (() -> Void)?
    private(set) var lastError: String?

    func start() {
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main) { [weak self] _ in
            self?.onRemoteChange?()
        }
        store.synchronize()
    }

    var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func loadApp() -> AppSettings? { decode(AppSettings.self, key: "app") }
    func saveApp(_ a: AppSettings) { encode(a, key: "app") }
    func loadPack(_ code: LanguageCode) -> PackProgress? { decode(PackProgress.self, key: "pack.\(code.rawValue)") }
    func savePack(_ p: PackProgress, for code: LanguageCode) { encode(p, key: "pack.\(code.rawValue)") }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard isAvailable, let raw = try? JSONEncoder().encode(value),
              let packed = try? (raw as NSData).compressed(using: .lzfse) as Data else { return }
        guard packed.count < 900_000 else { lastError = "\(key) is too large for iCloud key-value storage."; return }
        store.set(packed, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard isAvailable, let packed = store.data(forKey: key),
              let raw = try? (packed as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? JSONDecoder().decode(type, from: raw)
    }
}
