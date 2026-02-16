import Foundation

protocol GetHeroDetailUseCaseProtocol {
    func execute(id: Int) async throws -> Hero
}

struct GetHeroDetailUseCase: GetHeroDetailUseCaseProtocol {
    private let repository: HeroRepositoryProtocol

    init(repository: HeroRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: Int) async throws -> Hero {
        try await repository.getHeroDetail(id: id)
    }
}
