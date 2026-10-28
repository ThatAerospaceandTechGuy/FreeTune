import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var showErase = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0"
    }

    var body: some View {
        List {
            Section("Audio quality") {
                ForEach(AudioQuality.allCases) { option in
                    Button {
                        settings.quality = option
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
                            Spacer(minLength: 0)
                            if settings.quality == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.ftPrimary)
                                    .padding(.top, 2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Toggle(isOn: $settings.wifiOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi only")
                            .foregroundColor(.ftText)
                        Text("Queue downloads until Wi-Fi is available")
                            .font(.caption)
                            .foregroundColor(.ftSecondaryText)
                    }
                }
                .tint(.ftPrimary)
            } header: {
                Text("Downloads")
            } footer: {
                Text("Saved to Documents/FreeTune inside the FreeTune app folder. Browse it in Files → On My iPhone → FreeTune → FreeTune. Playlist downloads use a folder named after the playlist.")
            }

            Section("Playback") {
                Toggle(isOn: $settings.autoplay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Autoplay")
                            .foregroundColor(.ftText)
                        Text("Keep playing related songs when the queue ends")
                            .font(.caption)
                            .foregroundColor(.ftSecondaryText)
                    }
                }
                .tint(.ftPrimary)

                Text("Background playback and lock-screen / Control Center controls are built in. iOS doesn't allow a floating playback bar over other apps.")
                    .font(.caption)
                    .foregroundColor(.ftSecondaryText)
            }

            Section("Privacy") {
                Text("No accounts, analytics, ads or cloud sync. Your library, history, playlists and downloads stay on this device.")
                    .font(.subheadline)
                    .foregroundColor(.ftText)

                Button {
                    model.clearRecent()
                } label: {
                    Text("Clear recent history")
                        .foregroundColor(.ftPrimary)
                }

                Button {
                    showErase = true
                } label: {
                    Text("Erase all app data")
                        .foregroundColor(.ftError)
                }
            }

            Section("About") {
                Text("FreeTune \(version)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ftText)
                Text("Sideloaded, open-source build. GPL-3.0. Not affiliated with YouTube or Google.")
                    .font(.caption)
                    .foregroundColor(.ftSecondaryText)
                Text("Audio is streamed and downloaded from YouTube. Downloads are for personal use only. Respect copyright and YouTube's Terms of Service.")
                    .font(.caption)
                    .foregroundColor(.ftSecondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Erase everything?", isPresented: $showErase) {
            Button("Erase", role: .destructive) {
                model.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your likes, history, downloads, playlists and settings. This cannot be undone.")
        }
    }
}
