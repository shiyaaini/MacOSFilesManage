import Foundation

final class LocalizationManager {
    static let shared = LocalizationManager()
    
    private var currentBundle: Bundle = Bundle.main
    
    private init() {
        updateBundle()
    }
    
    func updateBundle() {
        let language = AppPreferences.shared.language
        
        if language == "system" {
            currentBundle = Bundle.main
            return
        }
        
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            currentBundle = Bundle.main
            return
        }
        
        currentBundle = bundle
    }
    
    func localizedString(_ key: String) -> String {
        return currentBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
