import Foundation

struct Endpoint {
    let baseURL: String
    let path: String
    let queryItems: [URLQueryItem]
    let method: String
    let headers: [String: String]

    init(
        baseURL: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
        self.method = method
        self.headers = headers
    }

    var url: URL? {
        var components = URLComponents(string: baseURL + path)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
}
