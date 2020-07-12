

import Foundation

public struct AccessToken : Hashable {
    public internal(set) static var current: AccessToken? {
        didSet {
            MinimalFacebook.currentConfig?.setTokenStringToKeychain(current?.tokenString)
        }
    }

    public var tokenString: String
    public static var isCurrentAccessTokenActive: Bool { current != nil }
    
    init(token: String) {
        tokenString = token
        AccessToken.current = self
    }
}

