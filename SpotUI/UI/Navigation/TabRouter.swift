import SwiftUI

/// Tab bar navigation — port of MainBottomNavigation.kt.
enum AppTab: String, CaseIterable {
    case home = "Home"
    case search = "Search"
    case library = "Library"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        }
    }
}
