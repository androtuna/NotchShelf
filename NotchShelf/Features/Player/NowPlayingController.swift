import AppKit
import MediaPlayer

@MainActor
final class NowPlayingController {
    var artworkImage: NSImage?
    private var commandsConfigured = false

    func setupCommands(_ viewModel: PlayerViewModel) {
        guard !commandsConfigured else { return }
        commandsConfigured = true

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak viewModel] _ in
            Task { @MainActor in viewModel?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak viewModel] _ in
            Task { @MainActor in viewModel?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak viewModel] _ in
            Task { @MainActor in viewModel?.togglePlay() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak viewModel] _ in
            Task { @MainActor in viewModel?.skip(15) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak viewModel] _ in
            Task { @MainActor in viewModel?.skip(-15) }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak viewModel] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in viewModel?.seek(to: event.positionTime) }
            return .success
        }
        center.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
        center.changePlaybackRateCommand.addTarget { [weak viewModel] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            Task { @MainActor in viewModel?.setRate(event.playbackRate) }
            return .success
        }
    }

    func update(title: String, author: String, duration: Double, elapsed: Double, rate: Float, playing: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPMediaItemPropertyAlbumTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? Double(rate) : 0.0,
        ]
        if let artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
