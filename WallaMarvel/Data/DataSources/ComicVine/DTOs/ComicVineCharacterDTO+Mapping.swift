import Foundation

extension ComicVineCharacterDTO {
    func toDomain() -> Hero {
        let imageURL: URL? = {
            if let urlString = image?.superURL ?? image?.originalURL ?? image?.screenLargeURL {
                return URL(string: urlString)
            }
            return nil
        }()

        let thumbURL: URL? = {
            if let urlString = image?.thumbURL ?? image?.smallURL ?? image?.mediumURL {
                return URL(string: urlString)
            }
            return nil
        }()

        let aliasesList: [String] = {
            guard let aliases = aliases, !aliases.isEmpty else { return [] }
            return aliases
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }()

        let firstAppearance: String? = {
            guard let issue = firstAppearedInIssue else { return nil }
            if let name = issue.name, let number = issue.issueNumber {
                return "\(name) #\(number)"
            }
            return issue.name
        }()

        return Hero(
            id: id,
            name: name ?? "Unknown",
            realName: realName,
            deck: deck,
            description: description,
            imageURL: imageURL,
            thumbURL: thumbURL,
            publisher: publisher?.name,
            powers: powers?.compactMap { $0.name } ?? [],
            teams: teams?.compactMap { $0.name } ?? [],
            firstAppearance: firstAppearance,
            aliases: aliasesList
        )
    }
}
