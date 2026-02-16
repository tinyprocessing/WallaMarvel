import Foundation
import Combine

final class HeroesListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    @Published private(set) var heroes: [Hero] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var hasMorePages = true
    @Published var searchQuery: String = ""

    private let getHeroesUseCase: GetHeroesUseCaseProtocol
    private let searchHeroesUseCase: SearchHeroesUseCaseProtocol
    private let pageSize = 20
    private var currentOffset = 0
    private var totalResults = 0
    private var isLoadingPage = false
    private var seenIds = Set<Int>()
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(getHeroesUseCase: GetHeroesUseCaseProtocol, searchHeroesUseCase: SearchHeroesUseCaseProtocol) {
        self.getHeroesUseCase = getHeroesUseCase
        self.searchHeroesUseCase = searchHeroesUseCase
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.handleSearchQueryChanged(query)
            }
            .store(in: &cancellables)
    }

    private func handleSearchQueryChanged(_ query: String) {
        resetPagination()
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            loadHeroes()
        } else {
            searchHeroes(query: query)
        }
    }

    func loadInitial() {
        guard state == .idle else { return }
        resetPagination()
        loadHeroes()
    }

    func loadNextPageIfNeeded(currentItem: Hero) {
        guard let lastHero = heroes.last,
              lastHero.id == currentItem.id,
              hasMorePages,
              !isLoadingPage else { return }

        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            loadHeroes()
        } else {
            searchHeroes(query: searchQuery)
        }
    }

    func refresh() {
        resetPagination()
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            loadHeroes()
        } else {
            searchHeroes(query: searchQuery)
        }
    }

    private func resetPagination() {
        searchTask?.cancel()
        currentOffset = 0
        totalResults = 0
        heroes = []
        seenIds = []
        hasMorePages = true
        isLoadingPage = false
    }

    private func appendUniqueHeroes(_ newHeroes: [Hero]) {
        let unique = newHeroes.filter { seenIds.insert($0.id).inserted }
        heroes.append(contentsOf: unique)
    }

    private func loadHeroes() {
        guard !isLoadingPage else { return }
        isLoadingPage = true

        if heroes.isEmpty {
            state = .loading
        }

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.getHeroesUseCase.execute(
                    offset: self.currentOffset,
                    limit: self.pageSize
                )
                guard !Task.isCancelled else { return }
                self.appendUniqueHeroes(result.heroes)
                self.totalResults = result.total
                self.currentOffset += result.heroes.count
                self.hasMorePages = self.currentOffset < result.total
                self.state = .loaded
            } catch {
                guard !Task.isCancelled else { return }
                if self.heroes.isEmpty {
                    self.state = .error(error.localizedDescription)
                }
            }
            self.isLoadingPage = false
        }
    }

    private func searchHeroes(query: String) {
        guard !isLoadingPage else { return }
        isLoadingPage = true

        if heroes.isEmpty {
            state = .loading
        }

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.searchHeroesUseCase.execute(
                    query: query,
                    offset: self.currentOffset,
                    limit: self.pageSize
                )
                guard !Task.isCancelled else { return }
                self.appendUniqueHeroes(result.heroes)
                self.totalResults = result.total
                self.currentOffset += result.heroes.count
                self.hasMorePages = self.currentOffset < result.total
                self.state = .loaded
            } catch {
                guard !Task.isCancelled else { return }
                if self.heroes.isEmpty {
                    self.state = .error(error.localizedDescription)
                }
            }
            self.isLoadingPage = false
        }
    }
}
