import UIKit

/// The app icon's long-press menu: the current language's first four tools, in place of a launcher widget.
enum QuickActions {
    static func update(for code: LanguageCode) {
        let engine = code.engine
        UIApplication.shared.shortcutItems = engine.tools.prefix(4).map { t in
            UIApplicationShortcutItem(type: "tool", localizedTitle: engine.title(t), localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: t.icon),
                                      userInfo: ["url": DeepLink.tool(t).absoluteString as NSString])
        }
    }

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let s = item.userInfo?["url"] as? String, let url = URL(string: s) else { return false }
        Router.shared.open(url)
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickActions.handle(item) }   // cold launch from a quick action
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.handle(shortcutItem))
    }
}
