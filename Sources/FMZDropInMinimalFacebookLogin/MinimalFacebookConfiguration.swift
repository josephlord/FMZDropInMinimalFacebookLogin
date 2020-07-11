
import Foundation

open class MinimalFacebook {

    /// Shared default config for all login managers to use
    /// When set it will update the current token based on the token the keychain provides
    public static var currentConfig: Config? {
        didSet {
            let token = currentConfig?.getTokenStringFromKeychain()
            if token != AccessToken.current?.tokenString {
                AccessToken.current = token.map { AccessToken(token: $0) }
            }
        }
    }

    /// Will cause logout if we get an error response when trying to use the token to get the users profile
    public class func validateCurrentToken() {
        assert(currentConfig != nil)
        guard let token = AccessToken.current?.tokenString,
            let url = URL(string:
                "https://graph.facebook.com/me?access_token=\(token)")
        else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: url) { (data, response, error) in
          guard let response = response as? HTTPURLResponse else {
            return
          }

          if response.statusCode < 200 || response.statusCode >= 300 {
            // If we have an error from the server AND the token we requested with is still current then log out.
            if token == AccessToken.current?.tokenString {
                MinimalLoginManager.shared.logOut()
            }
          }
        }.resume()
    }

    /// Required information for Facebook Login Operations
    public struct Config {
        public var facebookAppID: String
        public var getTokenStringFromKeychain:  () -> String?
        public var setTokenStringToKeychain:  (String?) -> Void
        public var openUrl: (URL) -> Void
        public var appScheme: String { return "fb" + facebookAppID }


        /// Sets up the required information for Facebook operations
        /// The reason it delegates the keychain operations to the app is to avoid using additional dependencies or code duplication in key chain
        /// handling.
        /// - Parameters:
        ///   - facebookAppID: The Facebook App ID to interact with, will read from FacebookAppID in Info.plist if nil
        ///   - getTokenStringFromKeychain: a closure to retreive a Facebook Token from secure storeage (KeyChain)
        ///   - setTokenStringToKeychain: a closure to store a Facebook Token to secure storage (KeyChain). nil should remove.
        ///   - openUrl: closure to open the Facebook login in external app (Safari). Should be proper openURL not diverted to a webview
        /// - Throws: Throws an error if there is no facebookAppID and none can be accessed from the main bundle info dictionary
        public init?(facebookAppID: String? = nil,
                    getTokenStringFromKeychain: @escaping () -> String?,
                    setTokenStringToKeychain: @escaping (String?) -> Void,
                    openUrl: @escaping (URL) -> Void) {

            guard let appId = facebookAppID ?? Bundle.main.infoDictionary?["FacebookAppID"] as? String
            else {
                assertionFailure("No FacebookAppID Add FacebookAppID property to app Info.plist or pass as argument in int")
                return nil
            }
            self.facebookAppID = appId
            self.getTokenStringFromKeychain = getTokenStringFromKeychain
            self.setTokenStringToKeychain = setTokenStringToKeychain
            self.openUrl = openUrl
        }
    }
}
