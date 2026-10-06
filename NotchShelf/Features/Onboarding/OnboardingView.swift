import SwiftUI

// İlk açılışta popover'ın üstüne binen tek ekranlık karşılama (spec §9).
struct OnboardingView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.gradient)
                .shadow(color: Theme.magenta.opacity(0.5), radius: 24, y: 14)

            VStack(spacing: 6) {
                Text("NotchShelf'a hoş geldin")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Kendi Audiobookshelf sunucuna bağlan,\nkitaplarını MacBook çentiğinden dinle.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("externaldrive.fill", "Sunucunu bağla", "URL + kullanıcı adı/şifre veya API token")
                bullet("books.vertical.fill", "Kütüphaneni aç", "Kitaplar ve kapaklar sunucudan gelir")
                bullet("checkmark.icloud.fill", "İlerleme senkron", "Kaldığın yer Audiobookshelf'e yazılır")
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                Button(action: onFinish) {
                    Text("Sunucumu bağla")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous).fill(Theme.gradient))
                        .shadow(color: Theme.magenta.opacity(0.4), radius: 20, y: 12)
                }
                .buttonStyle(.plain)

                Text("Hiçbir veri NotchShelf'a veya üçüncü tarafa gönderilmez; yalnızca senin sunucuna gider.")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.muted.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(Metrics.contentPadding)
        .frame(width: Metrics.popoverWidth, height: Metrics.popoverHeight)
        .background(Theme.base)
    }

    private func bullet(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.gradient)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
    }
}
