import Foundation

enum AppRecommendationPrompt {
    static let launchThreshold = 5

    private static let launchCountKey = "settings.appRecommendation.launchCount"
    private static let hasPresentedPromptKey = "settings.appRecommendation.hasPresentedPrompt"

    static func recordLaunch(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: hasPresentedPromptKey) else {
            return false
        }

        let currentCount = max(defaults.integer(forKey: launchCountKey), 0)
        let launchCount = min(currentCount + 1, launchThreshold)
        defaults.set(launchCount, forKey: launchCountKey)

        guard launchCount >= launchThreshold else { return false }
        defaults.set(true, forKey: hasPresentedPromptKey)
        return true
    }
}
