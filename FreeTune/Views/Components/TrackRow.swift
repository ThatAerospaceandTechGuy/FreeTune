import SwiftUI

struct TrackRow: View {
    let track: Track
    let isLiked: Bool
    let isDownloaded: Bool
    var removeWhenDownloaded: Bool = false
    let onPlay: () -> Void
    let onToggleLike: () -> Void
    let onDownload: () -> Void
    var onRemoveDownload: (() -> Void)?
    var onAddToPlaylist: (() -> Void)?
    var onRemoveFromPlaylist: (() -> Void)?

    private var hasMenu: Bool {
        onAddToPlaylist != nil || onRemoveFromPlaylist != nil
    }

    private var downloadIcon: String {
        if isDownloaded {
            return removeWhenDownloaded ? "trash" : "arrow.down.circle.fill"
        }
        return "arrow.down.circle"
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    ArtworkView(url: track.thumbnailURL)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.ftText)
                            .lineLimit(1)
                        Text("\(track.artist) · \(track.durationText)")
                            .font(.caption)
                            .foregroundColor(.ftSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isLiked ? .ftPrimary : .ftSecondaryText)
                    .frame(width: 33, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Unlike" : "Like")

            Button {
                if isDownloaded, removeWhenDownloaded, let onRemoveDownload {
                    onRemoveDownload()
                } else {
                    onDownload()
                }
            } label: {
                Image(systemName: downloadIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isDownloaded ? .ftPrimary : .ftSecondaryText)
                    .frame(width: 33, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDownloaded ? "Downloaded" : "Download")

            if hasMenu {
                Menu {
                    if let onAddToPlaylist {
                        Button("Add to playlist", action: onAddToPlaylist)
                    }
                    if let onRemoveFromPlaylist {
                        Button("Remove from playlist", role: .destructive, action: onRemoveFromPlaylist)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.ftSecondaryText)
                        .frame(width: 30, height: 44)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
