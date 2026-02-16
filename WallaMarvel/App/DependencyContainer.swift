import Foundation

final class DependencyContainer {
    static let shared = DependencyContainer()

    private lazy var apiClient: APIClient = URLSessionAPIClient()

    private lazy var comicVineDataSource: ComicVineDataSource = {
        let apiKey: String = {
            if let key = Bundle.main.infoDictionary?["COMIC_VINE_API_KEY"] as? String,
               !key.isEmpty, !key.hasPrefix("$(") {
                return key
            }
            return ""
        }()
        return ComicVineDataSource(apiClient: apiClient, apiKey: apiKey)
    }()

    private lazy var mockDataSource: MockDataSource = MockDataSource()

    private lazy var heroRepository: HeroRepositoryProtocol = {
        DefaultHeroRepository(
            primaryDataSource: comicVineDataSource,
            fallbackDataSource: mockDataSource
        )
    }()

    func makeGetHeroesUseCase() -> GetHeroesUseCaseProtocol {
        GetHeroesUseCase(repository: heroRepository)
    }

    func makeGetHeroDetailUseCase() -> GetHeroDetailUseCaseProtocol {
        GetHeroDetailUseCase(repository: heroRepository)
    }

    func makeSearchHeroesUseCase() -> SearchHeroesUseCaseProtocol {
        SearchHeroesUseCase(repository: heroRepository)
    }

    func makeHeroesListViewModel() -> HeroesListViewModel {
        HeroesListViewModel(
            getHeroesUseCase: makeGetHeroesUseCase(),
            searchHeroesUseCase: makeSearchHeroesUseCase()
        )
    }

    func makeHeroDetailViewModel(heroId: Int, heroName: String) -> HeroDetailViewModel {
        HeroDetailViewModel(
            heroId: heroId,
            heroName: heroName,
            getHeroDetailUseCase: makeGetHeroDetailUseCase()
        )
    }
}
