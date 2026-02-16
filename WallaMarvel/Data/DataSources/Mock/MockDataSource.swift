import Foundation

final class MockDataSource: HeroRepositoryProtocol {
    private lazy var allHeroes: [Hero] = {
        guard let url = Bundle.main.url(forResource: "MockData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mockItems = try? JSONDecoder().decode([MockHeroDTO].self, from: data) else {
            return []
        }
        return mockItems.map { $0.toDomain() }.sorted { $0.name < $1.name }
    }()

    func getHeroes(offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        let total = allHeroes.count
        let start = min(offset, total)
        let end = min(start + limit, total)
        let page = Array(allHeroes[start..<end])
        return (heroes: page, total: total)
    }

    func getHeroDetail(id: Int) async throws -> Hero {
        guard let hero = allHeroes.first(where: { $0.id == id }) else {
            throw APIError.noData
        }
        return hero
    }

    func searchHeroes(query: String, offset: Int, limit: Int) async throws -> (heroes: [Hero], total: Int) {
        let lowercased = query.lowercased()
        let filtered = allHeroes.filter { $0.name.lowercased().contains(lowercased) }
        let total = filtered.count
        let start = min(offset, total)
        let end = min(start + limit, total)
        let page = Array(filtered[start..<end])
        return (heroes: page, total: total)
    }
}

private struct MockHeroDTO: Decodable {
    let id: Int
    let name: String
    let realName: String?
    let deck: String?
    let publisher: String?
    let imageURL: String?
    let thumbURL: String?
    let powers: [String]
    let teams: [String]
    let firstAppearance: String?
    let aliases: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, deck, publisher, powers, teams, aliases
        case realName = "real_name"
        case imageURL = "image_url"
        case thumbURL = "thumb_url"
        case firstAppearance = "first_appearance"
    }

    func toDomain() -> Hero {
        Hero(
            id: id,
            name: name,
            realName: realName,
            deck: deck,
            description: deck,
            imageURL: imageURL.flatMap { URL(string: $0) },
            thumbURL: thumbURL.flatMap { URL(string: $0) },
            publisher: publisher,
            powers: powers,
            teams: teams,
            firstAppearance: firstAppearance,
            aliases: aliases
        )
    }
}
