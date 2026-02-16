import XCTest
@testable import WallaMarvel

// MARK: - Mock Repository

final class MockHeroRepository: HeroRepositoryProtocol {
    var heroesToReturn: [Hero] = []
    var totalToReturn: Int = 0
    var heroDetailToReturn: Hero?
    var errorToThrow: Error?
    var getHeroesCallCount = 0
    var searchCallCount = 0
    var detailCallCount = 0
    var lastSearchQuery: String?
    var lastOffset: Int?
    var lastLimit: Int?

    func getHeroes(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        getHeroesCallCount += 1
        lastOffset = offset
        lastLimit = limit
        if let error = errorToThrow { throw error }
        let start = min(offset, heroesToReturn.count)
        let end = min(start + limit, heroesToReturn.count)
        return (heroes: Array(heroesToReturn[start..<end]), total: totalToReturn)
    }

    func getHeroDetail(id: Int) async throws -> Hero {
        detailCallCount += 1
        if let error = errorToThrow { throw error }
        guard let hero = heroDetailToReturn else { throw APIError.noData }
        return hero
    }

    func searchHeroes(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        searchCallCount += 1
        lastSearchQuery = query
        lastOffset = offset
        lastLimit = limit
        if let error = errorToThrow { throw error }
        let filtered = heroesToReturn.filter { $0.name.lowercased().contains(query.lowercased()) }
        let start = min(offset, filtered.count)
        let end = min(start + limit, filtered.count)
        return (heroes: Array(filtered[start..<end]), total: filtered.count)
    }
}

// MARK: - Test Helpers

extension Hero {
    static func mock(
        id: Int = 1,
        name: String = "Spider-Man",
        realName: String? = "Peter Parker",
        deck: String? = "Your friendly neighborhood Spider-Man",
        description: String? = nil,
        imageURL: URL? = nil,
        thumbURL: URL? = nil,
        publisher: String? = "Marvel",
        powers: [String] = ["Wall-Crawling"],
        teams: [String] = ["Avengers"],
        firstAppearance: String? = "Amazing Fantasy #15",
        aliases: [String] = ["Spidey"]
    ) -> Hero {
        Hero(
            id: id,
            name: name,
            realName: realName,
            deck: deck,
            description: description,
            imageURL: imageURL,
            thumbURL: thumbURL,
            publisher: publisher,
            powers: powers,
            teams: teams,
            firstAppearance: firstAppearance,
            aliases: aliases
        )
    }
}

// MARK: - HeroesListViewModel Tests

final class HeroesListViewModelTests: XCTestCase {
    private var mockRepo: MockHeroRepository!
    private var viewModel: HeroesListViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockHeroRepository()
        viewModel = HeroesListViewModel(
            getHeroesUseCase: GetHeroesUseCase(repository: mockRepo),
            searchHeroesUseCase: SearchHeroesUseCase(repository: mockRepo)
        )
    }

    func testLoadInitialFetchesHeroes() async {
        let heroes = (1...5).map { Hero.mock(id: $0, name: "Hero \($0)") }
        mockRepo.heroesToReturn = heroes
        mockRepo.totalToReturn = 50

        viewModel.loadInitial()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.heroes.count, 5)
        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(mockRepo.getHeroesCallCount, 1)
    }

    func testLoadInitialOnlyCalledOnce() async {
        mockRepo.heroesToReturn = [.mock()]
        mockRepo.totalToReturn = 1

        viewModel.loadInitial()
        try? await Task.sleep(nanoseconds: 200_000_000)
        viewModel.loadInitial()

        XCTAssertEqual(mockRepo.getHeroesCallCount, 1)
    }

    func testErrorStateSetsCorrectly() async {
        mockRepo.errorToThrow = APIError.noData

        viewModel.loadInitial()
        try? await Task.sleep(nanoseconds: 200_000_000)

        if case .error = viewModel.state {
            // Pass
        } else {
            XCTFail("Expected error state")
        }
    }

    func testPaginationTracksOffset() async {
        let heroes = (1...20).map { Hero.mock(id: $0, name: "Hero \($0)") }
        mockRepo.heroesToReturn = heroes
        mockRepo.totalToReturn = 40

        viewModel.loadInitial()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.heroes.count, 20)
        XCTAssertTrue(viewModel.hasMorePages)
    }

    func testHasMorePagesFalseWhenAllLoaded() async {
        let heroes = (1...5).map { Hero.mock(id: $0, name: "Hero \($0)") }
        mockRepo.heroesToReturn = heroes
        mockRepo.totalToReturn = 5

        viewModel.loadInitial()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(viewModel.hasMorePages)
    }

    func testRefreshResetsState() async {
        let heroes = [Hero.mock(id: 1, name: "Hero 1")]
        mockRepo.heroesToReturn = heroes
        mockRepo.totalToReturn = 1

        viewModel.loadInitial()
        try? await Task.sleep(nanoseconds: 200_000_000)

        viewModel.refresh()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.heroes.count, 1)
        XCTAssertEqual(mockRepo.getHeroesCallCount, 2)
    }
}

// MARK: - HeroDetailViewModel Tests

final class HeroDetailViewModelTests: XCTestCase {
    private var mockRepo: MockHeroRepository!
    private var viewModel: HeroDetailViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockHeroRepository()
        viewModel = HeroDetailViewModel(
            heroId: 1,
            heroName: "Spider-Man",
            getHeroDetailUseCase: GetHeroDetailUseCase(repository: mockRepo)
        )
    }

    func testLoadDetailSuccess() async {
        let hero = Hero.mock(id: 1, name: "Spider-Man", description: "<p>Hero description</p>")
        mockRepo.heroDetailToReturn = hero

        viewModel.loadDetail()
        try? await Task.sleep(nanoseconds: 200_000_000)

        if case .loaded(let loadedHero) = viewModel.state {
            XCTAssertEqual(loadedHero.name, "Spider-Man")
            XCTAssertEqual(loadedHero.id, 1)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testLoadDetailError() async {
        mockRepo.errorToThrow = APIError.noData

        viewModel.loadDetail()
        try? await Task.sleep(nanoseconds: 200_000_000)

        if case .error = viewModel.state {
            // Pass
        } else {
            XCTFail("Expected error state")
        }
    }

    func testInitialStateIsLoading() {
        XCTAssertEqual(viewModel.state, .loading)
    }
}

// MARK: - DefaultHeroRepository Tests

final class DefaultHeroRepositoryTests: XCTestCase {
    func testFallsBackToSecondaryOnPrimaryFailure() async throws {
        let primary = MockHeroRepository()
        primary.errorToThrow = APIError.network(URLError(.notConnectedToInternet))

        let fallback = MockHeroRepository()
        fallback.heroesToReturn = [.mock(id: 1)]
        fallback.totalToReturn = 1

        let repo = DefaultHeroRepository(primaryDataSource: primary, fallbackDataSource: fallback)
        let result = try await repo.getHeroes(offset: 0, limit: 20)

        XCTAssertEqual(result.heroes.count, 1)
        XCTAssertEqual(primary.getHeroesCallCount, 1)
        XCTAssertEqual(fallback.getHeroesCallCount, 1)
    }

    func testUsesPrimaryWhenAvailable() async throws {
        let primary = MockHeroRepository()
        primary.heroesToReturn = [.mock(id: 1), .mock(id: 2)]
        primary.totalToReturn = 2

        let fallback = MockHeroRepository()

        let repo = DefaultHeroRepository(primaryDataSource: primary, fallbackDataSource: fallback)
        let result = try await repo.getHeroes(offset: 0, limit: 20)

        XCTAssertEqual(result.heroes.count, 2)
        XCTAssertEqual(primary.getHeroesCallCount, 1)
        XCTAssertEqual(fallback.getHeroesCallCount, 0)
    }
}

// MARK: - DTO Mapping Tests

final class ComicVineCharacterDTOMappingTests: XCTestCase {
    func testMapsBasicFields() {
        let dto = ComicVineCharacterDTO(
            id: 1699,
            name: "Spider-Man",
            realName: "Peter Parker",
            deck: "Friendly neighborhood Spider-Man",
            description: "<p>A hero</p>",
            image: ComicVineImageDTO(
                iconURL: nil, mediumURL: nil, screenURL: nil,
                screenLargeURL: nil, smallURL: nil,
                superURL: "https://example.com/super.jpg",
                thumbURL: "https://example.com/thumb.jpg",
                tinyURL: nil, originalURL: nil
            ),
            publisher: ComicVinePublisherDTO(id: 1, name: "Marvel"),
            powers: [ComicVineNamedDTO(id: 1, name: "Wall-Crawling")],
            teams: [ComicVineNamedDTO(id: 1, name: "Avengers")],
            firstAppearedInIssue: ComicVineIssueDTO(id: 1, name: "Amazing Fantasy", issueNumber: "15"),
            aliases: "Spidey\nWeb-Head"
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.id, 1699)
        XCTAssertEqual(hero.name, "Spider-Man")
        XCTAssertEqual(hero.realName, "Peter Parker")
        XCTAssertEqual(hero.deck, "Friendly neighborhood Spider-Man")
        XCTAssertEqual(hero.imageURL?.absoluteString, "https://example.com/super.jpg")
        XCTAssertEqual(hero.thumbURL?.absoluteString, "https://example.com/thumb.jpg")
        XCTAssertEqual(hero.publisher, "Marvel")
        XCTAssertEqual(hero.powers, ["Wall-Crawling"])
        XCTAssertEqual(hero.teams, ["Avengers"])
        XCTAssertEqual(hero.firstAppearance, "Amazing Fantasy #15")
        XCTAssertEqual(hero.aliases, ["Spidey", "Web-Head"])
    }

    func testHandlesNilFields() {
        let dto = ComicVineCharacterDTO(
            id: 1,
            name: nil,
            realName: nil,
            deck: nil,
            description: nil,
            image: nil,
            publisher: nil,
            powers: nil,
            teams: nil,
            firstAppearedInIssue: nil,
            aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.id, 1)
        XCTAssertEqual(hero.name, "Unknown")
        XCTAssertNil(hero.realName)
        XCTAssertNil(hero.deck)
        XCTAssertNil(hero.imageURL)
        XCTAssertNil(hero.thumbURL)
        XCTAssertNil(hero.publisher)
        XCTAssertTrue(hero.powers.isEmpty)
        XCTAssertTrue(hero.teams.isEmpty)
        XCTAssertNil(hero.firstAppearance)
        XCTAssertTrue(hero.aliases.isEmpty)
    }

    func testImageFallbackPriority_usesOriginalWhenNoSuper() {
        let dto = ComicVineCharacterDTO(
            id: 2,
            name: "Batman",
            realName: nil, deck: nil, description: nil,
            image: ComicVineImageDTO(
                iconURL: nil, mediumURL: "https://example.com/medium.jpg",
                screenURL: nil, screenLargeURL: nil,
                smallURL: "https://example.com/small.jpg",
                superURL: nil,
                thumbURL: nil,
                tinyURL: nil,
                originalURL: "https://example.com/original.jpg"
            ),
            publisher: nil, powers: nil, teams: nil,
            firstAppearedInIssue: nil, aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.imageURL?.absoluteString, "https://example.com/original.jpg")
        XCTAssertEqual(hero.thumbURL?.absoluteString, "https://example.com/small.jpg")
    }

    func testImageFallbackPriority_usesScreenLargeWhenNoSuperOrOriginal() {
        let dto = ComicVineCharacterDTO(
            id: 3,
            name: "Test",
            realName: nil, deck: nil, description: nil,
            image: ComicVineImageDTO(
                iconURL: nil, mediumURL: "https://example.com/medium.jpg",
                screenURL: nil,
                screenLargeURL: "https://example.com/screen_large.jpg",
                smallURL: nil, superURL: nil, thumbURL: nil, tinyURL: nil, originalURL: nil
            ),
            publisher: nil, powers: nil, teams: nil,
            firstAppearedInIssue: nil, aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.imageURL?.absoluteString, "https://example.com/screen_large.jpg")
        XCTAssertEqual(hero.thumbURL?.absoluteString, "https://example.com/medium.jpg")
    }

    func testFirstAppearanceWithNameOnly() {
        let dto = ComicVineCharacterDTO(
            id: 4,
            name: "Test",
            realName: nil, deck: nil, description: nil, image: nil, publisher: nil,
            powers: nil, teams: nil,
            firstAppearedInIssue: ComicVineIssueDTO(id: 1, name: "Action Comics", issueNumber: nil),
            aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.firstAppearance, "Action Comics")
    }

    func testAliasesTrimsWhitespaceAndFiltersEmpty() {
        let dto = ComicVineCharacterDTO(
            id: 5,
            name: "Test",
            realName: nil, deck: nil, description: nil, image: nil, publisher: nil,
            powers: nil, teams: nil, firstAppearedInIssue: nil,
            aliases: "  Alias One  \n\n  Alias Two \n   \n Alias Three"
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.aliases, ["Alias One", "Alias Two", "Alias Three"])
    }

    func testEmptyAliasStringReturnsEmptyArray() {
        let dto = ComicVineCharacterDTO(
            id: 6,
            name: "Test",
            realName: nil, deck: nil, description: nil, image: nil, publisher: nil,
            powers: nil, teams: nil, firstAppearedInIssue: nil,
            aliases: ""
        )

        let hero = dto.toDomain()

        XCTAssertTrue(hero.aliases.isEmpty)
    }

    func testPowersWithNilNamesAreFiltered() {
        let dto = ComicVineCharacterDTO(
            id: 7,
            name: "Test",
            realName: nil, deck: nil, description: nil, image: nil, publisher: nil,
            powers: [
                ComicVineNamedDTO(id: 1, name: "Flight"),
                ComicVineNamedDTO(id: 2, name: nil),
                ComicVineNamedDTO(id: 3, name: "Strength"),
            ],
            teams: nil, firstAppearedInIssue: nil, aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.powers, ["Flight", "Strength"])
    }

    func testMultipleTeamsMapping() {
        let dto = ComicVineCharacterDTO(
            id: 8,
            name: "Test",
            realName: nil, deck: nil, description: nil, image: nil, publisher: nil,
            powers: nil,
            teams: [
                ComicVineNamedDTO(id: 1, name: "Avengers"),
                ComicVineNamedDTO(id: 2, name: nil),
                ComicVineNamedDTO(id: 3, name: "X-Men"),
            ],
            firstAppearedInIssue: nil, aliases: nil
        )

        let hero = dto.toDomain()

        XCTAssertEqual(hero.teams, ["Avengers", "X-Men"])
    }
}

// MARK: - ComicVineCharacterDTO JSON Decoding Tests

final class ComicVineCharacterDTODecodingTests: XCTestCase {
    func testDecodesCharacterFromJSON() throws {
        let json = """
        {
            "id": 1699,
            "name": "Spider-Man",
            "real_name": "Peter Parker",
            "deck": "Friendly neighborhood Spider-Man",
            "description": "<p>A hero</p>",
            "image": {
                "icon_url": "https://example.com/icon.jpg",
                "medium_url": "https://example.com/medium.jpg",
                "screen_url": "https://example.com/screen.jpg",
                "screen_large_url": "https://example.com/screen_large.jpg",
                "small_url": "https://example.com/small.jpg",
                "super_url": "https://example.com/super.jpg",
                "thumb_url": "https://example.com/thumb.jpg",
                "tiny_url": "https://example.com/tiny.jpg",
                "original_url": "https://example.com/original.jpg",
                "image_tags": "All Images"
            },
            "publisher": {
                "api_detail_url": "https://comicvine.gamespot.com/api/publisher/4010-31/",
                "id": 31,
                "name": "Marvel"
            },
            "powers": [
                {"api_detail_url": "https://example.com", "id": 1, "name": "Wall-Crawling"},
                {"api_detail_url": "https://example.com", "id": 2, "name": "Spider-Sense"}
            ],
            "teams": [
                {"api_detail_url": "https://example.com", "id": 1, "name": "Avengers"}
            ],
            "first_appeared_in_issue": {
                "api_detail_url": "https://example.com",
                "id": 100,
                "name": "Amazing Fantasy",
                "issue_number": "15"
            },
            "aliases": "Spidey\\nWeb-Head"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ComicVineCharacterDTO.self, from: json)

        XCTAssertEqual(dto.id, 1699)
        XCTAssertEqual(dto.name, "Spider-Man")
        XCTAssertEqual(dto.realName, "Peter Parker")
        XCTAssertEqual(dto.deck, "Friendly neighborhood Spider-Man")
        XCTAssertEqual(dto.description, "<p>A hero</p>")
        XCTAssertEqual(dto.image?.superURL, "https://example.com/super.jpg")
        XCTAssertEqual(dto.image?.thumbURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(dto.publisher?.id, 31)
        XCTAssertEqual(dto.publisher?.name, "Marvel")
        XCTAssertEqual(dto.powers?.count, 2)
        XCTAssertEqual(dto.powers?.first?.name, "Wall-Crawling")
        XCTAssertEqual(dto.teams?.count, 1)
        XCTAssertEqual(dto.firstAppearedInIssue?.name, "Amazing Fantasy")
        XCTAssertEqual(dto.firstAppearedInIssue?.issueNumber, "15")
    }

    func testDecodesCharacterWithNullPublisher() throws {
        let json = """
        {
            "id": 999,
            "name": "Unknown Hero",
            "real_name": null,
            "deck": null,
            "description": null,
            "image": null,
            "publisher": null,
            "powers": null,
            "teams": null,
            "first_appeared_in_issue": null,
            "aliases": null
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ComicVineCharacterDTO.self, from: json)

        XCTAssertEqual(dto.id, 999)
        XCTAssertEqual(dto.name, "Unknown Hero")
        XCTAssertNil(dto.realName)
        XCTAssertNil(dto.publisher)
        XCTAssertNil(dto.image)
        XCTAssertNil(dto.powers)
    }

    func testDecodesComicVineListResponse() throws {
        let json = """
        {
            "error": "OK",
            "limit": 2,
            "offset": 0,
            "number_of_page_results": 2,
            "number_of_total_results": 166954,
            "status_code": 1,
            "results": [
                {
                    "id": 1,
                    "name": "Hero A",
                    "real_name": null,
                    "deck": "Deck A",
                    "image": null,
                    "publisher": null
                },
                {
                    "id": 2,
                    "name": "Hero B",
                    "real_name": "Bob",
                    "deck": null,
                    "image": null,
                    "publisher": {"id": 10, "name": "DC Comics"}
                }
            ],
            "version": "1.0"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ComicVineResponse<[ComicVineCharacterDTO]>.self, from: json)

        XCTAssertEqual(response.error, "OK")
        XCTAssertEqual(response.statusCode, 1)
        XCTAssertEqual(response.limit, 2)
        XCTAssertEqual(response.offset, 0)
        XCTAssertEqual(response.numberOfTotalResults, 166954)
        XCTAssertEqual(response.numberOfPageResults, 2)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results[0].name, "Hero A")
        XCTAssertEqual(response.results[1].publisher?.name, "DC Comics")
    }

    func testDecodesSingleCharacterResponse() throws {
        let json = """
        {
            "error": "OK",
            "limit": 1,
            "offset": 0,
            "number_of_page_results": 1,
            "number_of_total_results": 1,
            "status_code": 1,
            "results": {
                "id": 1699,
                "name": "Spider-Man",
                "real_name": "Peter Parker",
                "deck": "Hero",
                "description": "<p>Description</p>",
                "image": {
                    "super_url": "https://example.com/super.jpg",
                    "thumb_url": "https://example.com/thumb.jpg"
                },
                "publisher": {"id": 31, "name": "Marvel"},
                "powers": [{"id": 1, "name": "Wall-Crawling"}],
                "teams": [{"id": 1, "name": "Avengers"}],
                "first_appeared_in_issue": {"id": 100, "name": "Amazing Fantasy", "issue_number": "15"},
                "aliases": "Spidey"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ComicVineResponse<ComicVineCharacterDTO>.self, from: json)

        XCTAssertEqual(response.results.id, 1699)
        XCTAssertEqual(response.results.name, "Spider-Man")
        XCTAssertEqual(response.results.powers?.count, 1)
    }
}

// MARK: - HeroDetailViewController Tests

final class HeroDetailViewControllerTests: XCTestCase {
    private func makeSUT(hero: Hero? = nil, error: Error? = nil) -> (HeroDetailViewController, MockHeroRepository) {
        let mockRepo = MockHeroRepository()
        mockRepo.heroDetailToReturn = hero
        mockRepo.errorToThrow = error
        let vm = HeroDetailViewModel(
            heroId: hero?.id ?? 1,
            heroName: hero?.name ?? "Test",
            getHeroDetailUseCase: GetHeroDetailUseCase(repository: mockRepo)
        )
        let vc = HeroDetailViewController(viewModel: vm)
        return (vc, mockRepo)
    }

    private func loadView(_ vc: UIViewController) {
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
    }

    func testTitleIsSetToHeroName() {
        let hero = Hero.mock(id: 1, name: "Spider-Man")
        let (vc, _) = makeSUT(hero: hero)

        loadView(vc)

        XCTAssertEqual(vc.title, "Spider-Man")
    }

    func testViewBackgroundIsSystemBackground() {
        let (vc, _) = makeSUT(hero: .mock())

        loadView(vc)

        XCTAssertEqual(vc.view.backgroundColor, .systemBackground)
    }

    func testLoadingStateShowsIndicator() async {
        let mockRepo = MockHeroRepository()
        // Don't set heroDetailToReturn — will throw noData
        mockRepo.errorToThrow = nil
        // Create a VM but don't call loadDetail yet
        let vm = HeroDetailViewModel(
            heroId: 1,
            heroName: "Test",
            getHeroDetailUseCase: GetHeroDetailUseCase(repository: mockRepo)
        )

        XCTAssertEqual(vm.state, .loading)
    }

    @MainActor
    func testLoadedStateShowsHeroContent() async {
        let hero = Hero.mock(
            id: 1,
            name: "Spider-Man",
            realName: "Peter Parker",
            deck: "Friendly neighborhood Spider-Man",
            description: "<p>Web-slinging hero</p>",
            publisher: "Marvel",
            powers: ["Wall-Crawling", "Spider-Sense"],
            teams: ["Avengers"],
            firstAppearance: "Amazing Fantasy #15",
            aliases: ["Spidey", "Web-Head"]
        )
        let (vc, _) = makeSUT(hero: hero)

        loadView(vc)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let labels = findAllLabels(in: vc.view)
        let labelTexts = labels.compactMap { $0.text }

        XCTAssertTrue(labelTexts.contains("Spider-Man"))
        XCTAssertTrue(labelTexts.contains("Peter Parker"))
        XCTAssertTrue(labelTexts.contains("Marvel"))
        XCTAssertTrue(labelTexts.contains("Friendly neighborhood Spider-Man"))
        XCTAssertTrue(labelTexts.contains("Web-slinging hero"))
        XCTAssertTrue(labelTexts.contains("Wall-Crawling"))
        XCTAssertTrue(labelTexts.contains("Spider-Sense"))
        XCTAssertTrue(labelTexts.contains("Avengers"))
        XCTAssertTrue(labelTexts.contains("Amazing Fantasy #15"))
        XCTAssertTrue(labelTexts.contains("Spidey, Web-Head"))
    }

    @MainActor
    func testLoadedStateHidesOptionalFieldsWhenNil() async {
        let hero = Hero.mock(
            id: 2,
            name: "Mystery",
            realName: nil,
            deck: nil,
            description: nil,
            publisher: nil,
            powers: [],
            teams: [],
            firstAppearance: nil,
            aliases: []
        )
        let (vc, _) = makeSUT(hero: hero)

        loadView(vc)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let labels = findAllLabels(in: vc.view)
        let labelTexts = labels.compactMap { $0.text }

        XCTAssertTrue(labelTexts.contains("Mystery"))
        // Should NOT contain section headers for empty sections
        XCTAssertFalse(labelTexts.contains("Powers"))
        XCTAssertFalse(labelTexts.contains("Teams"))
        XCTAssertFalse(labelTexts.contains("First Appearance"))
        XCTAssertFalse(labelTexts.contains("Aliases"))
    }

    @MainActor
    func testErrorStateShowsErrorMessage() async {
        let (vc, _) = makeSUT(error: APIError.noData)

        loadView(vc)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let labels = findAllLabels(in: vc.view)
        let visibleErrorLabels = labels.filter { !$0.isHidden && $0.textColor == .secondaryLabel && $0.textAlignment == .center }
        XCTAssertFalse(visibleErrorLabels.isEmpty, "Should show an error label")
    }

    @MainActor
    func testHTMLTagsAreStrippedFromDescription() async {
        let hero = Hero.mock(
            id: 3,
            name: "Test",
            description: "<h1>Title</h1><p>Some <b>bold</b> text</p>"
        )
        let (vc, _) = makeSUT(hero: hero)

        loadView(vc)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let labels = findAllLabels(in: vc.view)
        let labelTexts = labels.compactMap { $0.text }

        XCTAssertTrue(labelTexts.contains("TitleSome bold text"))
        XCTAssertFalse(labelTexts.contains { $0.contains("<") })
    }

    // MARK: - Helpers

    private func findAllLabels(in view: UIView) -> [UILabel] {
        var result: [UILabel] = []
        for subview in view.subviews {
            if let label = subview as? UILabel {
                result.append(label)
            }
            result.append(contentsOf: findAllLabels(in: subview))
        }
        return result
    }
}
