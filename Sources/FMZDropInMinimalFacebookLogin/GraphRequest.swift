
import Foundation

open class FBSDKSettings {
    public var graphAPIVersion = "v7.0"
}

public enum HTTPMethod {
    case get, post, delete
    var description: String {
        switch self {
        case .get:    return "GET"
        case .post:   return "POST"
        case .delete: return "DELETE"
        }
    }
}

public class GraphRequest : NSObject {

    static let graphRequestUrlSession: URLSession = {
        return URLSession(configuration: .default)
    }()

    public let parameters: [String:String]
    public let tokenString: String?
    public let graphPath: String
    public let HTTPMethod: HTTPMethod
    public init(graphPath: String,
                parameters: [String: String]? = nil,
                tokenString: String? = nil,
                version: String? = nil,
                HTTPMethod: HTTPMethod = .get) {
        self.parameters = parameters ?? [:]
        self.tokenString = tokenString
        self.graphPath = graphPath
        self.HTTPMethod = HTTPMethod
    }

    ///Unlike the FB SDK version this provides the URLSession task instead of an FBSDKGraphRequest object
    /// Update your code accordingly if necessary
    public func start(completionHandler handler: @escaping (URLSessionTask?, Any?, Error?) -> Void) {
        guard nil != MinimalFacebook.currentConfig else {
            handler(nil, nil, NSError(
                        domain: minimalFacebookLoginErrorDomain,
                        code: -1,
                        userInfo: ["Reason" : "MinimalLoginManager.currentConfig is not set. Add FacebookAppID property to app Info.plist"]))
            return
        }
        guard let url = serializeURL().url else {
            handler(nil, nil, NSError(
                        domain: minimalFacebookLoginErrorDomain,
                        code: -6,
                        userInfo: ["Reason" : "Formed request URL is invalid"]))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = self.HTTPMethod.description
        var task: URLSessionDataTask? = nil
        task = GraphRequest.graphRequestUrlSession.dataTask(
            with: request) { (data, response, error) in
            GraphRequest.handleResponse(data: data, response: response, error: error, task: task, handler: handler)
        }
        task?.resume()
    }

    private static func handleResponse(data: Data?,
                        response: URLResponse?,
                        error: Error?,
                        task: URLSessionTask?,
                        handler: (URLSessionTask?, Any?, Error?) -> Void) {
        guard error == nil else {
            handler(task, nil, error)
            return
        }
        guard let response = response as? HTTPURLResponse else {
            handler(task, nil, NSError(
                        domain: minimalFacebookLoginErrorDomain,
                        code: -11,
                        userInfo: ["Reason":"No response info or error"]))
            return
        }
        guard (200...399).contains(response.statusCode) else {
            let err: NSError
            switch response.statusCode {
            case 401:
                err = NSError(
                    domain: minimalFacebookLoginErrorDomain,
                    code: response.statusCode,
                    userInfo: ["Reason":"Not authorised / bad token - if current will be removed / logged out"])
                MinimalLoginManager.shared.logOut()
            case 400...499:
                err = NSError(
                    domain: minimalFacebookLoginErrorDomain,
                    code: response.statusCode,
                    userInfo: ["Reason":"Request error.",
                               "Error": response])
            case 500...,
                 ...199:
                err = NSError(
                    domain: minimalFacebookLoginErrorDomain,
                    code: response.statusCode,
                    userInfo: ["Reason":"Unexpected or server error.",
                               "Error": response])
            case 300...399, _:
                assertionFailure("Should be handled by the guard")
                err = NSError(
                    domain: minimalFacebookLoginErrorDomain,
                    code: response.statusCode,
                    userInfo: ["Reason":"Unexpected or server error.",
                               "Error": response])
            }
            handler(task, nil, err)
            return
        }

            guard let data = data
            else {
                handler(task, nil, NSError(
                    domain: minimalFacebookLoginErrorDomain,
                    code: -20,
                    userInfo: ["Reason":"No Data."]))
                return
            }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            assert(jsonObject is [Any] || jsonObject is [String:Any])
            handler(task, jsonObject, nil)
        } catch {
            handler(task, nil, NSError(
                domain: minimalFacebookLoginErrorDomain,
                code: response.statusCode,
                userInfo: ["Reason":"Response parse error.",
                           "Error": response]))
        }

    }

    private func serializeURL() -> URLComponents {
        var urlComponents = URLComponents(string: "https://graph.facebook.com/")!
        urlComponents.path = graphPath
        let token = tokenString ?? AccessToken.current?.tokenString
        var modifiedParams = parameters
        modifiedParams["access_token"] = token
        urlComponents.queryItems = modifiedParams.map { key, value in URLQueryItem(name: key, value: value) }
        return urlComponents
    }
}
