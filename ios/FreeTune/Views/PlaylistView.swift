import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID

    @State private var showDelete = false

    private var playlist: Playlist? {
        library.playlist(id: playlistID)
    }

    private var tracks: [Track] {
        guard let playlist else { return [] }
        return library.tracks(in: playlist)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let playlist {
                    header(playlist)
                    actionRow(playlist)

                    if tracks.isEmpty {
                        EmptyStateView(
                            icon: "music.note.list",
                            title: "This playlist is empty",
                            message: "Add songs from Home or Search using the ⋯ menu."
                        )
                    } else {
                        ForEach(tracks) { track in
                            TrackRow(
                                track: track,
                                isLiked: library.isLiked(id: track.id),
                                isDownloaded: library.isDownloaded(id: track.id),
                                onPlay: { model.play(track, queue: tracks) },
                                onToggleLike: { model.toggleLike(track) },
                                onDownload: {
                                    model.download(track, folder: playlist.name)
                                },
                                onAddToPlaylist: {
                                    model.playlistPickerTrack = track
                                },
                                onRemoveFromPlaylist: {
                                    model.removeFromPlaylist(track, playlist: playlist)
                                }
                            )
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "Playlist not found",
                        message: "It may have been deleted."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Delete playlist", role: .destructive) {
                        showDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.semibold)
                }
            }
        }
        .alert("Delete playlist?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                if let playlist {
                    model.deletePlaylist(playlist)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(playlist?.name ?? "Playlist")\" will be removed. Downloaded files stay on this device.")
        }
    }

    private func header(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(tracks.count) songs")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.ftText)
            Text("Downloads to folder: \(playlist.name)/")
                .font(.caption)
                .foregroundColor(.ftSecondaryText)
        }
        .padding(.top, 2)
    }

    private func actionRow(_ playlist: Playlist) -> some View {
        HStack(spacing: 8) {
            Button {
                model.playPlaylist(playlist, tracks: tracks)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Play all")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.ftOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.ftPrimary))
            }
            .buttonStyle(.plain)

            Button {
                model.playPlaylist(playlist, tracks: tracks, shuffle: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                    Text("Shuffle")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.ftPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.ftPrimary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                model.requestPlaylistDownload(playlist)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.ftSecondaryText)
                    .frame(width: 40, height: 36)
                    .background(Circle().fill(Color.ftSurfaceVariant))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download playlist")
            .disabled(tracks.isEmpty)
            .opacity(tracks.isEmpty ? 0.45 : 1)
        }
        .padding(.bottom, 4)
    }
}
