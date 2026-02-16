import Foundation
import Combine

final class HeroDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(Hero)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.loaded(let a), .loaded(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    @Published private(set) var state: State = .loading

    let heroId: Int
    let heroName: String
    private let getHeroDetailUseCase: GetHeroDetailUseCaseProtocol

    init(heroId: Int, heroName: String, getHeroDetailUseCase: GetHeroDetailUseCaseProtocol) {
        self.heroId = heroId
        self.heroName = heroName
        self.getHeroDetailUseCase = getHeroDetailUseCase
    }

    func loadDetail() {
        state = .loading
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let hero = try await self.getHeroDetailUseCase.execute(id: self.heroId)
                self.state = .loaded(hero)
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }
}
