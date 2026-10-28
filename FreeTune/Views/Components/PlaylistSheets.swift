import SwiftUI

struct CreatePlaylistSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(create)
                } footer: {
                    Text("Downloads for a playlist are saved in a folder with the same name.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ftBackground)
            .navigationTitle("New playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(cleanName.isEmpty)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func create() {
        guard model.createPlaylist(name) != nil else { return }
        dismiss()
    }
}

struct AddToPlaylistSheet: View {
    let track: Track

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""

    private var cleanName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ArtworkView(url: track.thumbnailURL, corner: 9)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.ftText)
                                .lineLimit(2)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.ftSecondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Playlists") {
                    if library.playlists.isEmpty {
                        Text("No playlists yet. Create one below.")
                            .font(.subheadline)
                            .foregroundColor(.ftSecondaryText)
                    } else {
                        ForEach(library.playlists) { playlist in
                            Button {
                                model.addToPlaylist(track, playlist: playlist)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.ftPrimary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.body)
                                            .foregroundColor(.ftText)
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) songs")
                                            .font(.caption)
                                            .foregroundColor(.ftSecondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.ftSecondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("New playlist") {
                    TextField("Playlist name", text: $newName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(createAndAdd)

                    Button {
                        createAndAdd()
                    } label: {
                        Label("Create and add", systemImage: "plus")
                            .foregroundColor(cleanName.isEmpty ? .ftSecondaryText : .ftPrimary)
                    }
                    .disabled(cleanName.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ftBackground)
            .navigationTitle("Add to playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func createAndAdd() {
        guard model.createPlaylistAndAdd(newName, track: track) else { return }
        dismiss()
    }
}

struct PlaylistDownloadSheet: View {
    let request: PlaylistDownloadRequest

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var quality: AudioQuality
    @State private var skipDownloaded = true

    init(request: PlaylistDownloadRequest, initialQuality: AudioQuality) {
        self.request = request
        _quality = State(initialValue: initialQuality)
    }

    private var alreadyDownloaded: Int {
        request.tracks.filter { library.isDownloaded(id: $0.id) }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.playlist.name)
                        .font(.headline)
                        .foregroundColor(.ftText)
                    Text("\(request.tracks.count) songs · saved to Documents/FreeTune/\(request.playlist.name)/")
                        .font(.caption)
                        .foregroundColor(.ftSecondaryText)
                    if alreadyDownloaded > 0 {
                        Text("\(alreadyDownloaded) of \(request.tracks.count) already downloaded")
                            .font(.caption)
                            .foregroundColor(.ftSecondaryText)
                    }
                }

                Section("Quality") {
                    ForEach(AudioQuality.allCases) { option in
                        Button {
                            quality = option
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.body)
                                        .foregroundColor(.ftText)
                                    Text(option.detail)
                                        .font(.caption)
                                        .foregroundColor(.ftSecondaryText)
                                }
                                Spacer()
                                if quality == option {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundColor(.ftPrimary)
                                        .padding(.top, 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle(isOn: $skipDownloaded) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Skip already downloaded")
                                .foregroundColor(.ftText)
                            Text("Only fetch songs that aren't on this device. Turn off to download the whole playlist again.")
                                .font(.caption)
                                .foregroundColor(.ftSecondaryText)
                        }
                    }
                    .tint(.ftPrimary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ftBackground)
            .navigationTitle("Download playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(skipDownloaded ? "Download" : "Download all") {
                        model.confirmPlaylistDownload(
                            request,
                            quality: quality,
                            skipDownloaded: skipDownloaded
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
