import SwiftUI

@MainActor
final class NotchHUDState: ObservableObject {
    @Published var isExpanded = false
}

struct NotchHUDView: View {
    @ObservedObject var state: NotchHUDState
    @ObservedObject var player: PlayerViewModel
    @ObservedObject private var server = ServerViewModel.shared
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let isSimulated: Bool

    @State private var scrub: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 0) {
            strip
            if state.isExpanded {
                panel
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: state.isExpanded ? 20 : 8,
                bottomTrailingRadius: state.isExpanded ? 20 : 8,
                topTrailingRadius: 0
            )
            .fill(Color.black)
        )
        // Notch'un siyahıyla eriyen gövdeye ince bir ışık kenarı: ayrımı hissettirir.
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: state.isExpanded ? 20 : 8,
                bottomTrailingRadius: state.isExpanded ? 20 : 8,
                topTrailingRadius: 0
            )
            .stroke(Theme.edgeHighlight, lineWidth: state.isExpanded ? 1 : 0)
        )
        .shadow(color: .black.opacity(state.isExpanded ? 0.55 : 0), radius: 18, y: 8)
        .animation(AppAnimation.hud, value: state.isExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { scrub = player.currentTime }
        .onChange(of: player.currentTime) { time in
            if !isScrubbing { scrub = time }
        }
    }

    private var strip: some View {
        HStack {
            Image(systemName: "headphones")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(state.isExpanded ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.muted))
                .padding(.leading, 10)

            Spacer(minLength: notchWidth - 40)

            Waveform(active: player.isPlaying)
                .padding(.trailing, 10)
        }
        .frame(height: notchHeight + 6)
    }

    private var panel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                coverArt

                VStack(alignment: .leading, spacing: 3) {
                    Text(player.title.isEmpty ? L("Kitap seçilmedi") : player.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(player.author.isEmpty ? L("Kütüphaneden bir kitap seç") : player.author)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
            }

            VStack(spacing: 4) {
                Slider(
                    value: $scrub,
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing { player.seek(to: scrub) }
                    }
                )
                .controlSize(.mini)
                .tint(Theme.violet)
                .disabled(player.duration == 0)

                HStack {
                    Text(Formatters.time(scrub)).font(.system(size: 9)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text("-\(Formatters.time(max(player.duration - scrub, 0)))")
                        .font(.system(size: 9)).foregroundStyle(Theme.muted)
                }
            }

            HStack(spacing: 28) {
                hudButton("gobackward.15", size: 16) { player.skip(-15) }
                hudButton(player.isPlaying ? "pause.fill" : "play.fill", size: 22, prominent: true) { player.togglePlay() }
                hudButton("goforward.15", size: 16) { player.skip(15) }
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.muted)
                Slider(
                    value: Binding(
                        get: { Double(player.volume) },
                        set: { player.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.muted)
            }

            if isSimulated {
                Text("Simüle notch — bu makinede fiziksel notch yok")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.muted.opacity(0.6))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // Kitap kapağı; yüklenene kadar gradyan yer tutucu.
    @ViewBuilder private var coverArt: some View {
        if let book = player.currentBook {
            CoverImage(itemId: book.id, client: server.client, cornerRadius: 14)
                .frame(width: 56, height: 56)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                )
        }
    }

    private func hudButton(_ symbol: String, size: CGFloat, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(prominent ? Theme.ink : Theme.muted)
                .frame(width: prominent ? 44 : 32, height: prominent ? 44 : 32)
                .background(
                    Circle().fill(prominent ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.cardFill))
                )
                .overlay(Circle().stroke(Theme.cardBorder))
        }
        .buttonStyle(.plain)
    }
}

private struct Waveform: View {
    let active: Bool
    @State private var up = false
    private let base: [CGFloat] = [6, 10, 14, 9, 5]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(base.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.violet.opacity(0.8))
                    .frame(width: 2.5, height: base[index] * (active ? (up ? 1.0 : 0.45) : 0.7))
            }
        }
        .animation(
            active
                ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
            value: up
        )
        .onAppear { up = active }
        .onChange(of: active) { value in up = value }
    }
}

#Preview {
    NotchHUDView(
        state: {
            let state = NotchHUDState()
            state.isExpanded = true
            return state
        }(),
        player: PlayerViewModel.shared,
        notchWidth: 200,
        notchHeight: 32,
        isSimulated: true
    )
    .frame(width: 380, height: 300)
}
