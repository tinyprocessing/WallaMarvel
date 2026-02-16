import Foundation

protocol HeroRepositoryProtocol {
    func getHeroes(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int)
    func getHeroDetail(id: Int) async throws -> Hero
    func searchHeroes(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int)
}
