import Foundation

struct ComicVineCharacterDTO: Decodable {
    let id: Int
    let name: String?
    let realName: String?
    let deck: String?
    let description: String?
    let image: ComicVineImageDTO?
    let publisher: ComicVinePublisherDTO?
    let powers: [ComicVineNamedDTO]?
    let teams: [ComicVineNamedDTO]?
    let firstAppearedInIssue: ComicVineIssueDTO?
    let aliases: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case realName = "real_name"
        case deck
        case description
        case image
        case publisher
        case powers
        case teams
        case firstAppearedInIssue = "first_appeared_in_issue"
        case aliases
    }
}

struct ComicVineImageDTO: Decodable {
    let iconURL: String?
    let mediumURL: String?
    let screenURL: String?
    let screenLargeURL: String?
    let smallURL: String?
    let superURL: String?
    let thumbURL: String?
    let tinyURL: String?
    let originalURL: String?

    enum CodingKeys: String, CodingKey {
        case iconURL = "icon_url"
        case mediumURL = "medium_url"
        case screenURL = "screen_url"
        case screenLargeURL = "screen_large_url"
        case smallURL = "small_url"
        case superURL = "super_url"
        case thumbURL = "thumb_url"
        case tinyURL = "tiny_url"
        case originalURL = "original_url"
    }
}

struct ComicVinePublisherDTO: Decodable {
    let id: Int?
    let name: String?
}

struct ComicVineNamedDTO: Decodable {
    let id: Int?
    let name: String?
}

struct ComicVineIssueDTO: Decodable {
    let id: Int?
    let name: String?
    let issueNumber: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case issueNumber = "issue_number"
    }
}
