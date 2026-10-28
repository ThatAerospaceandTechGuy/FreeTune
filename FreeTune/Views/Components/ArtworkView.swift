import SwiftUI

struct ArtworkView: View {
    let url: String?
    var corner: CGFloat = 12

    var body: some View {
        Color.ftSurfaceVariant
            .overlay {
                if let link = imageURL {
                    AsyncImage(
                        url: link,
                        transaction: Transaction(animation: .easeInOut(duration: 0.18))
                    ) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholder
                        default:
                            placeholder.opacity(0.6)
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var imageURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        if url.hasPrefix("//") {
            return URL(string: "https:" + url)
        }
        return URL(string: url)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ftSurfaceVariant, Color.ftPrimaryContainer.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.ftSecondaryText)
        }
    }
}
