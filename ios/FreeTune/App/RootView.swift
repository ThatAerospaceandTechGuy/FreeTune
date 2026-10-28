import SwiftUI

private enum RootTab: Hashable {
    case home
    case search
    case library
    case settings
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: PlayerManager

    @State private var selection: RootTab = .home
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                NavigationStack {
                    HomeView(onOpenSearch: { selection = .search })
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(RootTab.home)

                NavigationStack {
                    SearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(RootTab.search)

                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "rectangle.stack.fill")
                }
                .tag(RootTab.library)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(RootTab.settings)
            }
            .tint(.ftPrimary)

            if player.current != nil {
                VStack {
                    Spacer()
                    MiniPlayerView {
                        showPlayer = true
                    }
                    .padding(.bottom, 49)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }

            if showPlayer, player.current != nil {
                NowPlayingView {
                    showPlayer = false
                }
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }

            toastOverlay
                .zIndex(20)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: player.current?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showPlayer)
        .onChange(of: player.current) { newValue in
            if newValue == nil {
                showPlayer = false
            }
        }
        .sheet(item: $model.playlistPickerTrack) { track in
            AddToPlaylistSheet(track: track)
        }
        .sheet(item: $model.playlistDownloadRequest) { request in
            PlaylistDownloadSheet(
                request: request,
                initialQuality: model.settings.quality
            )
        }
    }

    private var toastOverlay: some View {
        VStack {
            if let toast = model.toast {
                Text(toast.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ftBackground)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.ftText))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
    }
}
