import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var server: ServerViewModel
    @EnvironmentObject var rootState: RootView.State

    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    private let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    var body: some View {
        Group {
            if player.currentBook == nil && player.title.isEmpty {
                emptyState
            } else {
                content
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "headphones").font(.system(size: 30)).foregroundStyle(Theme.gradient)
            Text("Şu an çalan yok").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            Text("Dinlemeye başlamak için kütüphaneden bir kitap seç.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button {
                rootState.selectedTab = .library
            } label: {
                Text("Kütüphaneye git")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Theme.gradient))
            }
            .buttonStyle(.plain)
            if let error = player.lastError {
                Text(error).font(.system(size: 10)).foregroundStyle(Theme.pink).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var content: some View {
        VStack(spacing: 10) {
            artwork
            titles
            scrubber
            controls
            rateAndVolume
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var artwork: some View {
        Group {
            if let book = player.currentBook {
                CoverImage(itemId: book.id, client: server.client, cornerRadius: 14)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.cardFill)
                    Image(systemName: "waveform").font(.system(size: 30)).foregroundStyle(Theme.gradient)
                }
            }
        }
        .frame(width: 100, height: 100)
        .shadow(color: Theme.magenta.opacity(0.3), radius: 12, y: 8)
    }

    private var titles: some View {
        VStack(spacing: 3) {
            Text(player.title)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                .lineLimit(2).multilineTextAlignment(.center)
            Text(player.author)
                .font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
            syncBadge
        }
    }

    // Progress sync'in canlı çalıştığını gösteren küçük işaret.
    @ViewBuilder private var syncBadge: some View {
        if player.currentBook != nil {
            HStack(spacing: 4) {
                Image(systemName: player.isSyncing ? "arrow.clockwise" : "checkmark.icloud")
                    .font(.system(size: 9))
                Text(player.isSyncing
                     ? L("Kaydediliyor…")
                     : player.lastSyncAt.map { LF("Kaydedildi %@", $0.relativeDescription) } ?? L("Kaydedilmeyi bekliyor"))
                    .font(.system(size: 9))
            }
            .foregroundStyle(Theme.muted.opacity(0.75))
        }
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubbing ? scrubValue : player.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 0.01),
                onEditingChanged: { editing in
                    scrubbing = editing
                    if !editing { player.seek(to: scrubValue) }
                }
            )
            .tint(Theme.violet)
            HStack {
                Text(Formatters.time(scrubbing ? scrubValue : player.currentTime))
                Spacer()
                Text("-" + Formatters.time(max(player.duration - (scrubbing ? scrubValue : player.currentTime), 0)))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.muted)
        }
    }

    private var controls: some View {
        HStack(spacing: 26) {
            controlButton("gobackward.15") { player.skip(-15) }
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.gradient))
                    .shadow(color: Theme.magenta.opacity(0.4), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            controlButton("goforward.15") { player.skip(15) }
        }
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private var rateAndVolume: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(rates, id: \.self) { rate in
                    let selected = abs(player.playbackRate - rate) < 0.01
                    Button {
                        player.setRate(rate)
                    } label: {
                        Text(rate == 1.0 ? "1x" : String(format: "%gx", rate))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(selected ? Theme.ink : Theme.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Theme.cardFill : .clear))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? Theme.cardBorder : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(Theme.muted)
                Slider(value: Binding(get: { Double(player.volume) }, set: { player.setVolume(Float($0)) }), in: 0...1)
                    .tint(Theme.violet)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
        }
    }
}
