import Foundation

/// Project links shown in the app and sent to Wikimedia in the User-Agent, as its API etiquette asks.
enum AppInfo {
    static let repository = "https://github.com/ChiChou/ExUno"
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    static var userAgent: String { "ExUno/\(version) (\(repository))" }
}
