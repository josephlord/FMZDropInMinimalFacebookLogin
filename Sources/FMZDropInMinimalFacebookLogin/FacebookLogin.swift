

import UIKit

public typealias ApplicationDelegate = FacebookLogin.ApplicationDelegate

public struct FacebookLogin {
    public struct ApplicationDelegate {
        public static let shared = ApplicationDelegate()
        public func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any?) -> Bool {
            return MinimalLoginManager.shared.handle(url: url)
        }
        public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
            return MinimalLoginManager.shared.handle(url: url)
        }
    }
}
