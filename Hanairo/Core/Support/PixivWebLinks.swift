import Foundation

enum PixivWebLinks {
    static func artwork(id: Int) -> URL {
        URL(string: "https://www.pixiv.net/artworks/\(id)")!
    }

    static func user(id: Int) -> URL {
        URL(string: "https://www.pixiv.net/users/\(id)")!
    }

    static func sauceNAO(imageURL: URL) -> URL? {
        var components = URLComponents(string: "https://saucenao.com/search.php")
        components?.queryItems = [URLQueryItem(name: "url", value: imageURL.absoluteString)]
        return components?.url
    }
}
