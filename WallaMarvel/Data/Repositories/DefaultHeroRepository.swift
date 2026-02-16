import Foundation

final class DefaultHeroRepository: HeroRepositoryProtocol {
    private let primaryDataSource: HeroRepositoryProtocol
    private let fallbackDataSource: HeroRepositoryProtocol

    init(primaryDataSource: HeroRepositoryProtocol, fallbackDataSource: HeroRepositoryProtocol) {
        self.primaryDataSource = primaryDataSource
        self.fallbackDataSource = fallbackDataSource
    }

    func getHeroes(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        do {
            return try await primaryDataSource.getHeroes(offset: offset, limit: limit)
        } catch {
            return try await fallbackDataSource.getHeroes(offset: offset, limit: limit)
        }
    }

    func getHeroDetail(id: Int) async throws -> Hero {
        do {
            return try await primaryDataSource.getHeroDetail(id: id)
        } catch {
            return try await fallbackDataSource.getHeroDetail(id: id)
        }
    }

    func searchHeroes(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        do {
            return try await primaryDataSource.searchHeroes(query: query, offset: offset, limit: limit)
        } catch {
            return try await fallbackDataSource.searchHeroes(query: query, offset: offset, limit: limit)
        }
    }
}
