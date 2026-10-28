import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore

    let onClose: () -> Void

    @State private var dragPosition: Double?

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                let maximum = max(player.duration, 1)
                return min(dragPosition ?? player.position, maximum)
            },
            set: { dragPosition = $0 }
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ftPrimary.opacity(0.30),
                    Color.ftBackground,
                    Color.ftBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let track = player.current {
                    ScrollView {
                        VStack(spacing: 20) {
                            artwork(track)
                            trackInfo(track)
                            actionRow(track)
                            progressSection
                            transportControls
                            autoplayCard
                            errorSection
                            upNext
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    EmptyStateView(
                        icon: "music.note",
                        title: "Nothing playing",
                        message: "Choose a song from Home, Search or your library."
                    )
                    Spacer()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.ftSecondaryText.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.ftText)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.ftSurfaceVariant))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close player")

                Spacer()

                Text("NOW PLAYING")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundColor(.ftSecondaryText)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private func artwork(_ track: Track) -> some View {
        ArtworkView(url: track.thumbnailURL, corner: 24)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 360)
            .shadow(color: Color.black.opacity(0.24), radius: 24, y: 12)
            .padding(.top, 4)
    }

    private func trackInfo(_ track: Track) -> some View {
        VStack(spacing: 5) {
            Text(track.title)
                .font(.ftRounded(25, weight: .bold))
                .foregroundColor(.ftText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(track.artist)
                .font(.body)
                .foregroundColor(.ftSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionRow(_ track: Track) -> some View {
        let liked = library.isLiked(id: track.id)
        let downloaded = library.isDownloaded(id: track.id)

        return HStack(spacing: 18) {
            Button {
                model.toggleLike(track)
            } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(liked ? .ftPrimary : .ftSecondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(liked ? "Unlike" : "Like")

            Button {
                model.playlistPickerTrack = track
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.ftSecondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to playlist")

            Button {
                model.download(track)
            } label: {
                Image(systemName: downloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(downloaded ? .ftPrimary : .ftSecondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(downloaded ? "Downloaded" : "Download")

            Spacer(minLength: 0)

            Text(statusText(downloaded: downloaded))
                .font(.caption)
                .foregroundColor(.ftSecondaryText)
                .lineLimit(1)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 2) {
            Slider(
                value: sliderBinding,
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if !editing, let target = dragPosition {
                        player.seek(to: target)
                        dragPosition = nil
                    }
                }
            )
            .tint(.ftPrimary)

            HStack {
                Text(Track.formatDuration(seconds: dragPosition ?? player.position))
                Spacer()
                Text(Track.formatDuration(seconds: player.duration))
            }
            .font(.caption2)
            .foregroundColor(.ftSecondaryText)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 42) {
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.ftText)
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous")

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.ftPrimary)
                        .frame(width: 76, height: 76)
                    if player.isLoading {
                        ProgressView()
                            .tint(.ftOnPrimary)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.ftOnPrimary)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.ftText)
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next")
        }
        .frame(maxWidth: .infinity)
    }

    private var autoplayCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Autoplay")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ftText)
                Text(
                    player.autoplayLoading
                        ? "Finding more songs like this…"
                        : "Keep playing related songs when the queue ends"
                )
                .font(.caption)
                .foregroundColor(.ftSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $settings.autoplay)
                .labelsHidden()
                .tint(.ftPrimary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ftSurfaceVariant)
        )
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = player.error {
            ErrorCard(message: error)
        }
    }

    @ViewBuilder
    private var upNext: some View {
        if player.queue.count > 1 {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                Text("Up next · \(max(0, player.queue.count - player.queueIndex - 1)) songs")
                    .font(.caption)
                Spacer()
            }
            .foregroundColor(.ftSecondaryText)
            .padding(.horizontal, 4)
        }
    }

    private func statusText(downloaded: Bool) -> String {
        if player.autoplayLoading { return "Finding more songs…" }
        if downloaded { return "Downloaded" }
        return "Streaming"
    }
}
