import SwiftUI
import UIKit

extension Color {
    static let ftPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.725, green: 0.651, blue: 1.0, alpha: 1)
            : UIColor(red: 0.353, green: 0.247, blue: 0.839, alpha: 1)
    })

    static let ftOnPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.043, blue: 0.302, alpha: 1)
            : .white
    })

    static let ftPrimaryContainer = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.165, blue: 0.478, alpha: 1)
            : UIColor(red: 0.902, green: 0.871, blue: 1.0, alpha: 1)
    })

    static let ftOnPrimaryContainer = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.910, green: 0.878, blue: 1.0, alpha: 1)
            : UIColor(red: 0.102, green: 0.043, blue: 0.302, alpha: 1)
    })

    static let ftBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.043, green: 0.043, blue: 0.059, alpha: 1)
            : UIColor(red: 0.992, green: 0.984, blue: 1.0, alpha: 1)
    })

    static let ftSurface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.071, green: 0.071, blue: 0.094, alpha: 1)
            : .white
    })

    static let ftSurfaceVariant = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.118, blue: 0.149, alpha: 1)
            : UIColor(red: 0.910, green: 0.894, blue: 0.961, alpha: 1)
    })

    static let ftText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.925, green: 0.918, blue: 1.0, alpha: 1)
            : UIColor(red: 0.106, green: 0.106, blue: 0.129, alpha: 1)
    })

    static let ftSecondaryText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.725, green: 0.714, blue: 0.784, alpha: 1)
            : UIColor(red: 0.282, green: 0.271, blue: 0.310, alpha: 1)
    })

    static let ftOutline = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.290, green: 0.282, blue: 0.345, alpha: 1)
            : UIColor(red: 0.475, green: 0.459, blue: 0.498, alpha: 1)
    })

    static let ftError = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.706, blue: 0.671, alpha: 1)
            : UIColor(red: 0.729, green: 0.102, blue: 0.102, alpha: 1)
    })
}

extension Font {
    static func ftRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func ftScreen() -> some View {
        background(Color.ftBackground.ignoresSafeArea())
    }
}
