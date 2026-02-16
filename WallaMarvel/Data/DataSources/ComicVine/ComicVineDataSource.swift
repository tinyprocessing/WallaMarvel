import Foundation

final class ComicVineDataSource: HeroRepositoryProtocol {
    private let apiClient: APIClient
    private let apiKey: String

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func getHeroes(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        let endpoint = ComicVineEndpoints.characters(apiKey: apiKey, offset: offset, limit: limit)
        let response: ComicVineResponse<[ComicVineCharacterDTO]> = try await apiClient.request(endpoint)
        let heroes = response.results.map { $0.toDomain() }
        return (heroes: heroes, total: response.numberOfTotalResults)
    }

    func getHeroDetail(id: Int) async throws -> Hero {
        let endpoint = ComicVineEndpoints.characterDetail(apiKey: apiKey, id: id)
        let response: ComicVineResponse<ComicVineCharacterDTO> = try await apiClient.request(endpoint)
        return response.results.toDomain()
    }

    func searchHeroes(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        let endpoint = ComicVineEndpoints.searchCharacters(apiKey: apiKey, query: query, offset: offset, limit: limit)
        let response: ComicVineResponse<[ComicVineCharacterDTO]> = try await apiClient.request(endpoint)
        let heroes = response.results.map { $0.toDomain() }
        return (heroes: heroes, total: response.numberOfTotalResults)
    }
}
