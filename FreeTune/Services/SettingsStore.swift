import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    @Published var quality: AudioQuality {
        didSet { defaults.set(quality.rawValue, forKey: Keys.quality) }
    }

    @Published var wifiOnly: Bool {
        didSet { defaults.set(wifiOnly, forKey: Keys.wifiOnly) }
    }

    @Published var autoplay: Bool {
        didSet { defaults.set(autoplay, forKey: Keys.autoplay) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedQuality = defaults.string(forKey: Keys.quality)
            .flatMap(AudioQuality.init(rawValue:))
        quality = savedQuality ?? .high
        wifiOnly = defaults.bool(forKey: Keys.wifiOnly)

        if defaults.object(forKey: Keys.autoplay) == nil {
            autoplay = true
        } else {
            autoplay = defaults.bool(forKey: Keys.autoplay)
        }
    }

    func reset() {
        quality = .high
        wifiOnly = false
        autoplay = true
    }

    private enum Keys {
        static let quality = "freetune.audioQuality"
        static let wifiOnly = "freetune.wifiOnly"
        static let autoplay = "freetune.autoplay"
    }
}
