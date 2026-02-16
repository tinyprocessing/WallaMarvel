import Foundation

enum ComicVineEndpoints {
    private static let baseURL = "https://comicvine.gamespot.com/api"

    static func characters(apiKey: String, offset: Int, limit: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/characters/",
            queryItems: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "field_list", value: "id,name,deck,image,real_name,publisher"),
                URLQueryItem(name: "sort", value: "name:asc"),
            ]
        )
    }

    static func characterDetail(apiKey: String, id: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/character/4005-\(id)/",
            queryItems: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "field_list", value: "id,name,real_name,deck,description,image,publisher,powers,teams,first_appeared_in_issue,aliases"),
            ]
        )
    }

    static func searchCharacters(apiKey: String, query: String, offset: Int, limit: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/search/",
            queryItems: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "resources", value: "character"),
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "field_list", value: "id,name,deck,image,real_name,publisher"),
            ]
        )
    }
}
