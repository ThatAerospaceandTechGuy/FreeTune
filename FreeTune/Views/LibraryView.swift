import SwiftUI

private enum LibraryTab: String, CaseIterable, Identifiable {
    case playlists = "Playlists"
    case liked = "Liked"
    case downloads = "Downloads"
    case recent = "Recent"

    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: DownloadManager

    @State private var tab: LibraryTab = .playlists
    @State private var showCreate = false
    @State private var pendingDelete: Playlist?

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    currentContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if tab == .playlists {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("New playlist")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreatePlaylistSheet()
        }
        .alert(
            "Delete playlist?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { playlist in
            Button("Delete", role: .destructive) {
                model.deletePlaylist(playlist)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { playlist in
            Text("\"\(playlist.name)\" will be removed. Downloaded files stay on this device.")
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryTab.allCases) { item in
                    FilterChip(
                        title: item.rawValue,
                        selected: tab == item
                    ) {
                        tab = item
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var currentContent: some View {
        switch tab {
        case .playlists:
            playlistsContent
        case .liked:
            likedContent
        case .downloads:
            downloadsContent
        case .recent:
            recentContent
        }
    }

    @ViewBuilder
    private var playlistsContent: some View {
        if library.playlists.isEmpty {
            VStack(spacing: 4) {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No playlists yet",
                    message: "Group songs and download each playlist into its own folder."
                )
                Button {
                    showCreate = true
                } label: {
                    Label("Create playlist", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ftOnPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.ftPrimary))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        } else {
            ForEach(library.playlists) { playlist in
                PlaylistCard(
                    playlist: playlist,
                    onPlay: { model.playPlaylist(playlist) },
                    onShuffle: { model.playPlaylist(playlist, shuffle: true) },
                    onDownload: { model.requestPlaylistDownload(playlist) },
                    onDelete: { pendingDelete = playlist }
                )
            }
        }
    }

    @ViewBuilder
    private var likedContent: some View {
        if library.liked.isEmpty {
            EmptyStateView(
                icon: "heart",
                title: "No liked songs",
                message: "Tap the heart on any song and it will show up here."
            )
        } else {
            ForEach(library.liked) { track in
                TrackRow(
                    track: track,
                    isLiked: true,
                    isDownloaded: library.isDownloaded(id: track.id),
                    onPlay: { model.play(track, queue: library.liked) },
                    onToggleLike: { model.toggleLike(track) },
                    onDownload: { model.download(track) },
                    onAddToPlaylist: { model.playlistPickerTrack = track }
                )
            }
        }
    }

    @ViewBuilder
    private var downloadsContent: some View {
        let active = downloads.activeStatuses
        let failed = downloads.failedStatuses
        let saved = library.downloaded

        if active.isEmpty && failed.isEmpty && saved.isEmpty {
            EmptyStateView(
                icon: "arrow.down.circle",
                title: "No downloads yet",
                message: "Downloads are saved on this device and play without a connection."
            )
        } else {
            if !active.isEmpty {
                SectionHeader(title: "In progress")
                ForEach(active) { status in
                    DownloadProgressRow(status: status)
                }
            }

            if !failed.isEmpty {
                SectionHeader(title: "Failed")
                ForEach(failed) { status in
                    FailedDownloadRow(
                        status: status,
                        onRetry: { model.retryDownload(status) },
                        onDismiss: { model.dismissDownload(status.track.id) }
                    )
                }
            }

            if !saved.isEmpty {
                SectionHeader(title: "Downloaded · \(saved.count)")
                ForEach(saved) { track in
                    TrackRow(
                        track: track,
                        isLiked: library.isLiked(id: track.id),
                        isDownloaded: true,
                        removeWhenDownloaded: true,
                        onPlay: { model.play(track, queue: saved) },
                        onToggleLike: { model.toggleLike(track) },
                        onDownload: {},
                        onRemoveDownload: { model.removeDownload(track) },
                        onAddToPlaylist: { model.playlistPickerTrack = track }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recentContent: some View {
        if library.recent.isEmpty {
            EmptyStateView(
                icon: "clock",
                title: "No listening history",
                message: "Songs you play will appear here."
            )
        } else {
            SectionHeader(
                title: "\(library.recent.count) played",
                actionTitle: "Clear",
                action: { model.clearRecent() }
            )
            ForEach(library.recent) { track in
                TrackRow(
                    track: track,
                    isLiked: library.isLiked(id: track.id),
                    isDownloaded: library.isDownloaded(id: track.id),
                    onPlay: { model.play(track, queue: library.recent) },
                    onToggleLike: { model.toggleLike(track) },
                    onDownload: { model.download(track) },
                    onAddToPlaylist: { model.playlistPickerTrack = track }
                )
            }
        }
    }
}

private struct PlaylistCard: View {
    let playlist: Playlist
    let onPlay: () -> Void
    let onShuffle: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                PlaylistView(playlistID: playlist.id)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.ftPrimaryContainer)
                            .frame(width: 52, height: 52)
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.ftOnPrimaryContainer)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(playlist.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.ftText)
                            .lineLimit(1)
                        Text("\(playlist.trackCount) songs · downloads to \(playlist.name)/")
                            .font(.caption)
                            .foregroundColor(.ftSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.ftSecondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                SmallActionButton(title: "Play", icon: "play.fill", action: onPlay)
                SmallActionButton(title: "Shuffle", icon: "shuffle", action: onShuffle)
                Spacer()

                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.ftSecondaryText)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download playlist")

                Menu {
                    Button("Play", action: onPlay)
                    Button("Shuffle", action: onShuffle)
                    Button("Download playlist…", action: onDownload)
                    Button("Delete playlist", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.ftSecondaryText)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ftSurfaceVariant)
        )
    }
}
