

import Foundation

public struct AccessToken : Hashable {
    public internal(set) static var current: AccessToken? {
        didSet {
            MinimalFacebook.currentConfig?.setTokenStringToKeychain(current?.tokenString)
        }
    }

    public var tokenString: String
    
    init(token: String) {
        tokenString = token
        AccessToken.current = self
    }
}

