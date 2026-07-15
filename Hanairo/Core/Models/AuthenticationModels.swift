import Foundation

struct AuthTokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String
    let user: AuthenticatedUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthTokenEnvelope: Decodable, Sendable {
    let response: AuthTokenResponse
}

struct AuthenticatedUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let account: String
    let mailAddress: String?
    let isPremium: Bool
    let profileImageURLs: AuthProfileImageURLs

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case mailAddress = "mail_address"
        case isPremium = "is_premium"
        case profileImageURLs = "profile_image_urls"
    }

    var numericID: Int? { Int(id) }
}

struct AuthProfileImageURLs: Codable, Hashable, Sendable {
    let small: URL?
    let medium: URL?
    let large: URL?

    enum CodingKeys: String, CodingKey {
        case small = "px_16x16"
        case medium = "px_50x50"
        case large = "px_170x170"
    }
}

struct StoredCredentials: Codable, Hashable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expirationDate: Date

    var needsRefresh: Bool {
        expirationDate.timeIntervalSinceNow < 60
    }
}

struct AuthorizationPreparation: Hashable, Sendable {
    let url: URL
    let verifier: String
}

enum PixivAuthorizationFlow: Hashable, Sendable {
    case login
    case accountCreation
}
