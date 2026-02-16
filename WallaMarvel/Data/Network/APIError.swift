import Foundation

enum APIError: LocalizedError {
    case network(URLError)
    case decoding(DecodingError)
    case serverError(statusCode: Int)
    case noData
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .noData:
            return "No data received from server"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}
