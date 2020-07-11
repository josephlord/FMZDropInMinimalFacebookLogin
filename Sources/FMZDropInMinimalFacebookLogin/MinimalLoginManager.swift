

import UIKit
import AuthenticationServices

public let minimalFacebookLoginErrorDomain = "com.human-friendly.minimalfacebooklogin"

public func LoginManager() -> MinimalLoginManager {
    MinimalLoginManager.shared
}

@available(iOSApplicationExtension, unavailable)
@available(iOS 9.0, *)
open class MinimalLoginManager {
    public static let shared: MinimalLoginManager = MinimalLoginManager(config: MinimalFacebook.currentConfig)

    private var activeSession: Any?
    let config: MinimalFacebook.Config?

    private init(config: MinimalFacebook.Config?) {
        let conf = config ?? MinimalFacebook.currentConfig
        assert(conf != nil, "No configuration.")
        self.config = conf
    }
    private var lastRequestState: String?
    private var lastRequestHandler: ((LoginManagerLoginResult?, Error?) -> Void)?

    open func logOut() {
        AccessToken.current = nil
        config?.setTokenStringToKeychain("")
    }

    @available(iOS 9.0, *)
    public func logIn(permissions: [String],
               from: UIViewController?,
               handler: @escaping ((LoginManagerLoginResult?, Error?) -> Void)) {
        guard let config = config else {
            handler(nil, NSError(
            domain: minimalFacebookLoginErrorDomain,
            code: -1,
            userInfo: ["Reason" : "MinimalLoginManager.currentConfig is not set. Add FacebookAppID property to app Info.plist"]))
            return
        }
        let appID = config.facebookAppID
        let state = UUID().uuidString
        self.lastRequestState = state
        let callbackScheme = config.appScheme
        let baseURLString = "https://www.facebook.com/v7.0/dialog/oauth"
        let urlString = "\(baseURLString)"
        + "?client_id=\(appID)"
        + "&redirect_uri=\(callbackScheme)://authorize"
        + "&scope=\(permissions.joined(separator: ","))"
        + "&response_type=token%20granted_scopes"
        + "&state=\(state)"
        guard let url = URL(string: urlString) else {
            handler(nil, NSError(
                domain: minimalFacebookLoginErrorDomain,
                code: -2,
                userInfo: ["Reason" : "Software error, malformed URL"]))
            assertionFailure()
            return
        }
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            //loginManagersWithSessions.append(self)
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme) { (url, error) in
                    defer {
                        self.activeSession = nil // create and break retain cycle
                    }
                    if let error = error {
                        handler(nil, error)
                        return
                    }
                    guard let url = url else { return }
                    do {
                        let result = try LoginManagerLoginResult(url: url, state: state)
                        AccessToken.current = result?.token
                        handler(result, nil)
                    } catch {
                        handler(nil, error)
                    }
                }
            if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                session.presentationContextProvider = from
            }
            session.start()
            self.activeSession = session
        } else {
            lastRequestHandler = handler
            config.openUrl(url)
        }
    }

    func handle(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let state = self.lastRequestState,
            components.scheme != nil,
            config?.appScheme == components.scheme
        else {
            return false
        }
        do {
            let result = try LoginManagerLoginResult(url: url, state: state)
            AccessToken.current = result?.token
            lastRequestHandler?(result, nil)
            lastRequestHandler = nil
            lastRequestState = nil
            return true
        } catch {
            return false
        }
    }
}

public struct LoginManagerLoginResult {
    public let token: AccessToken?
    public let isCancelled: Bool
    public let grantedPermissions: Set<String>
    public let declinedPermissions: Set<String>

    init?(url: URL, state: String) throws {
        let fixedUrl = URL(string: url.absoluteString.replacingOccurrences(of: "#", with: "?")) ?? url
        guard let components = URLComponents(url: fixedUrl, resolvingAgainstBaseURL: false),
            let receivedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        else {
            throw NSError(
                domain: minimalFacebookLoginErrorDomain,
                code: -4,
                userInfo: ["reason":"Invalid URL callback URL"]) }

        guard state == receivedState else {
            return nil
        }
        assert(components.scheme == MinimalFacebook.currentConfig?.appScheme)
        let gScopes = components.queryItems?.first { $0.name == "granted_scopes" }?.value
        let dScopes = components.queryItems?.first { $0.name == "denied_scopes" }?.value
        let tokenString = components.queryItems?.first { $0.name == "access_token" }?.value
        grantedPermissions = Self.parse(scope: gScopes)
        declinedPermissions = Self.parse(scope: dScopes)
        token = tokenString.map { AccessToken(token: $0) }
        isCancelled = false
    }

    private static func parse(scope: String?) -> Set<String> {
        Set(scope?.split(separator: ",").map { String($0) } ?? [])
    }
}

@available(iOS 12.0, *)
@available(iOSApplicationExtension, unavailable)
extension UIViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(
      for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        assert(view.window != nil)
        return view.window ?? UIApplication.shared.windows.first!
    }
}
