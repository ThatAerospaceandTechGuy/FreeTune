import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    let onOpen: () -> Void

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.position / player.duration, 0), 1)
    }

    var body: some View {
        if let track = player.current {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Color.ftOutline.opacity(0.25)
                        Color.ftPrimary
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 8) {
                    Button(action: onOpen) {
                        HStack(spacing: 11) {
                            ArtworkView(url: track.thumbnailURL, corner: 8)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.ftText)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundColor(.ftSecondaryText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Group {
                            if player.isLoading {
                                ProgressView()
                                    .tint(.ftPrimary)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.ftText)
                            }
                        }
                        .frame(width: 38, height: 44)
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.ftText)
                            .frame(width: 38, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.ftSurface)
                    .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 8)
        }
    }
}
