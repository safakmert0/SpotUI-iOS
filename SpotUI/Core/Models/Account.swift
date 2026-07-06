import Foundation

struct Account: Codable {
    let name: String
    let email: String
    let imageUrl: String
    let plan: String

    init(name: String = "", email: String = "", imageUrl: String = "", plan: String = "") {
        self.name = name
        self.email = email
        self.imageUrl = imageUrl
        self.plan = plan
    }
}
