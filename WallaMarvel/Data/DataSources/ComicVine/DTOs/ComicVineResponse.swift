import Foundation

struct ComicVineResponse<T: Decodable>: Decodable {
    let error: String
    let limit: Int
    let offset: Int
    let numberOfPageResults: Int
    let numberOfTotalResults: Int
    let statusCode: Int
    let results: T

    enum CodingKeys: String, CodingKey {
        case error
        case limit
        case offset
        case numberOfPageResults = "number_of_page_results"
        case numberOfTotalResults = "number_of_total_results"
        case statusCode = "status_code"
        case results
    }
}
