import Foundation

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    
    var displayName: String {
        switch self {
        case .system: return "language.system".localized
        case .zhHans: return "language.chinese".localized
        case .en: return "language.english".localized
        }
    }
}
