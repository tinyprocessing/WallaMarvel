import Foundation

protocol SearchHeroesUseCaseProtocol {
    func execute(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int)
}

struct SearchHeroesUseCase: SearchHeroesUseCaseProtocol {
    private let repository: HeroRepositoryProtocol

    init(repository: HeroRepositoryProtocol) {
        self.repository = repository
    }

    func execute(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        try await repository.searchHeroes(query: query, offset: offset, limit: limit)
    }
}
