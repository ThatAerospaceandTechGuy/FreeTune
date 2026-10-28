import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore

    let onOpenSearch: () -> Void

    private let quickPicks = [
        "Top songs 2026",
        "Lo-fi beats",
        "Chill hits",
        "Workout music",
        "Trending music"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                searchButton
                mixCard
                quickPickRow

                if !library.recent.isEmpty {
                    trackStrip(
                        title: "Jump back in",
                        tracks: Array(library.recent.prefix(8))
                    )
                }

                if !library.liked.isEmpty {
                    trackStrip(
                        title: "Liked songs",
                        tracks: Array(library.liked.prefix(8))
                    )
                }

                discoverSection
            }
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.ensureDiscoverLoaded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("FreeTune")
                .font(.ftRounded(34, weight: .bold))
                .foregroundColor(.ftText)
            Text("Free, local and ad-free.")
                .font(.subheadline)
                .foregroundColor(.ftSecondaryText)
        }
        .padding(.horizontal, 20)
    }

    private var searchButton: some View {
        Button(action: onOpenSearch) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.ftSecondaryText)
                Text("Search songs, artists, albums")
                    .font(.subheadline)
                    .foregroundColor(.ftSecondaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.ftSurfaceVariant)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var mixCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR DAILY MIX")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundColor(.ftOnPrimaryContainer.opacity(0.72))

            Text(model.discover.query)
                .font(.ftRounded(27, weight: .bold))
                .foregroundColor(.ftOnPrimaryContainer)
                .lineLimit(2)
                .padding(.top, 6)

            Text(mixSubtitle)
                .font(.footnote)
                .foregroundColor(.ftOnPrimaryContainer.opacity(0.78))
                .lineLimit(1)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Button(action: shuffleDiscover) {
                    ZStack {
                        Circle()
                            .fill(Color.ftPrimary)
                            .frame(width: 48, height: 48)
                        if model.discover.loading {
                            ProgressView()
                                .tint(.ftOnPrimary)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.ftOnPrimary)
                                .offset(x: 1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(model.discover.loading ? "Loading mix…" : "Shuffle play")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.ftOnPrimaryContainer)
            }
            .padding(.top, 16)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.ftPrimaryContainer, Color.ftSurfaceVariant],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var mixSubtitle: String {
        if let first = model.discover.results.first {
            return "\(model.discover.results.count) tracks ready · \(first.artist) and more"
        }
        return "Pick a mood below and start listening"
    }

    private var quickPickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPicks, id: \.self) { pick in
                    FilterChip(
                        title: pick,
                        selected: model.discover.query == pick
                    ) {
                        model.loadDiscover(pick)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Discover · \(model.discover.query)")
                .padding(.horizontal, 20)

            if model.discover.loading && model.discover.results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.ftPrimary)
                    Spacer()
                }
                .padding(.vertical, 36)
            } else if let error = model.discover.error {
                ErrorCard(message: error) {
                    model.loadDiscover(model.discover.query)
                }
                .padding(.horizontal, 20)
            } else if model.discover.results.isEmpty {
                EmptyStateView(
                    icon: "music.note",
                    title: "Nothing here yet",
                    message: "Try a different mood or search for something."
                )
            } else {
                ForEach(Array(model.discover.results.prefix(20))) { track in
                    TrackRow(
                        track: track,
                        isLiked: library.isLiked(id: track.id),
                        isDownloaded: library.isDownloaded(id: track.id),
                        onPlay: { model.play(track, queue: model.discover.results) },
                        onToggleLike: { model.toggleLike(track) },
                        onDownload: { model.download(track) },
                        onAddToPlaylist: { model.playlistPickerTrack = track }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func trackStrip(title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tracks) { track in
                        TrackCard(track: track) {
                            model.play(track, queue: tracks)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func shuffleDiscover() {
        if model.discover.results.isEmpty {
            model.loadDiscover(model.discover.query)
            return
        }
        let shuffled = model.discover.results.shuffled()
        guard let first = shuffled.first else { return }
        model.play(first, queue: shuffled)
    }
}

private struct TrackCard: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ArtworkView(url: track.thumbnailURL, corner: 14)
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.14), radius: 8, y: 4)

                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ftText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.ftSecondaryText)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
