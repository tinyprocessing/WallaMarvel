import Foundation

protocol GetHeroesUseCaseProtocol {
    func execute(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int)
}

struct GetHeroesUseCase: GetHeroesUseCaseProtocol {
    private let repository: HeroRepositoryProtocol

    init(repository: HeroRepositoryProtocol) {
        self.repository = repository
    }

    func execute(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        try await repository.getHeroes(offset: offset, limit: limit)
    }
}
