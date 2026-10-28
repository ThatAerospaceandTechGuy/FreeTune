import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @FocusState private var focused: Bool

    private var queryBinding: Binding<String> {
        Binding(
            get: { model.search.query },
            set: { model.setSearchQuery($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            content
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.ftSecondaryText)

            TextField("Songs, artists, albums…", text: queryBinding)
                .focused($focused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.ftText)
                .onSubmit {
                    model.submitSearch()
                    focused = false
                }

            if !model.search.query.isEmpty {
                Button {
                    model.setSearchQuery("")
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.ftSecondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ftSurfaceVariant)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if model.search.loading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.ftPrimary)
                Text("Searching YouTube…")
                    .font(.footnote)
                    .foregroundColor(.ftSecondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.search.error {
            ScrollView {
                ErrorCard(message: error) {
                    model.submitSearch()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if !model.search.hasSearched {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Find your next favorite",
                message: "Results appear automatically as you type. You can also press search."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.search.results.isEmpty {
            EmptyStateView(
                icon: "music.note.list",
                title: "No results",
                message: "Nothing matched \"\(model.search.query)\". Try another spelling or artist."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(model.search.results.count) results")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.ftSecondaryText)
                    .padding(.vertical, 8)

                ForEach(model.search.results) { track in
                    TrackRow(
                        track: track,
                        isLiked: library.isLiked(id: track.id),
                        isDownloaded: library.isDownloaded(id: track.id),
                        onPlay: { model.play(track, queue: model.search.results) },
                        onToggleLike: { model.toggleLike(track) },
                        onDownload: { model.download(track) },
                        onAddToPlaylist: { model.playlistPickerTrack = track }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
