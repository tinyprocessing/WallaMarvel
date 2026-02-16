import Foundation

struct Hero: Identifiable, Hashable {
    let id: Int
    let name: String
    let realName: String?
    let deck: String?
    let description: String?
    let imageURL: URL?
    let thumbURL: URL?
    let publisher: String?
    let powers: [String]
    let teams: [String]
    let firstAppearance: String?
    let aliases: [String]
}
