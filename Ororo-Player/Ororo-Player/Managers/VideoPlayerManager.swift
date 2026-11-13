//
//  VideoPlayerManager.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import AVKit
import AVFoundation
import CoreMedia
import OroroKit

/// A ceiling on the HLS variant AVPlayer may pick. AVPlayer plays the highest
/// rung at or below the cap and still drops lower on poor bandwidth; exact
/// variant pinning is not supported by design. `.auto` removes the cap.
enum QualityCap: String, CaseIterable {

    case auto
    case p480
    case p720
    case p1080
    case uhd4k

    var title: String {
        switch self {
        case .auto: return "quality_auto".localized()
        case .p480: return "480p"
        case .p720: return "720p"
        case .p1080: return "1080p"
        case .uhd4k: return "4K"
        }
    }

    /// The ladder's rungs have odd widths (2000x1080, 3998x2160), so cap by
    /// height only.
    fileprivate var maximumResolution: CGSize {
        switch self {
        case .auto: return .zero
        case .p480: return CGSize(width: 9999, height: 480)
        case .p720: return CGSize(width: 9999, height: 720)
        case .p1080: return CGSize(width: 9999, height: 1080)
        case .uhd4k: return CGSize(width: 9999, height: 2160)
        }
    }
}

final class VideoPlayerManager {

    // MARK: - Properties
    let player: AVPlayer
    private let progress: Double
    private var itemStatusObserver: NSKeyValueObservation?
    private var presentationSizeObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?

    private static let qualityCapKey = "player.qualityCap"
    private(set) var qualityCap: QualityCap = .auto

    /// The caps this item's variant ladder can honor; all of them until the
    /// master playlist has been inspected.
    private(set) var availableCaps: [QualityCap] = QualityCap.allCases

    /// The cap to present as selected: a persisted cap above this item's
    /// ladder behaves like Auto without overwriting the saved preference.
    var effectiveCap: QualityCap {
        return availableCaps.contains(qualityCap) ? qualityCap : .auto
    }

    /// Fires on the main queue whenever the playing variant changes;
    /// `.zero` until the first frame is ready.
    var onPresentationSizeChange: ((CGSize) -> Void)?
    /// Fires on the main queue once the variant ladder has been inspected.
    var onAvailableCapsChange: (() -> Void)?
    /// Fires on the main queue when playback pauses or resumes.
    var onPauseStateChange: ((Bool) -> Void)?

    // MARK: - Life cycle
    init(url: URL, progress: Double) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        self.progress = progress
        activateAudioSession()
        selectAudibleOptionWhenReady(for: playerItem)
        observePresentationSize(of: playerItem)
        observeRate()
        loadVariantLadder(from: url)

        if let raw = UserDefaults.standard.string(forKey: VideoPlayerManager.qualityCapKey),
            let restored = QualityCap(rawValue: raw) {
            apply(restored)
        }
    }

    deinit {
        itemStatusObserver?.invalidate()
        presentationSizeObserver?.invalidate()
        rateObserver?.invalidate()
    }

    // MARK: - Quality
    func apply(_ cap: QualityCap) {
        qualityCap = cap
        UserDefaults.standard.set(cap.rawValue, forKey: VideoPlayerManager.qualityCapKey)
        player.currentItem?.preferredMaximumResolution = cap.maximumResolution
    }

    /// Extracts the caps supported by an HLS master playlist from its
    /// `#EXT-X-STREAM-INF` variants, e.g. `RESOLUTION=2000x1080`. Returns all
    /// caps when no resolutions can be found.
    static func availableCaps(inMasterPlaylist playlist: String) -> [QualityCap] {
        var maxHeight = 0
        let regex = try? NSRegularExpression(pattern: "RESOLUTION=\\d+x(\\d+)")
        let range = NSRange(playlist.startIndex..., in: playlist)
        regex?.enumerateMatches(in: playlist, range: range) { (match, _, _) in
            guard let match = match,
                let heightRange = Range(match.range(at: 1), in: playlist),
                let height = Int(playlist[heightRange]) else { return }
            maxHeight = max(maxHeight, height)
        }
        guard maxHeight > 0 else { return QualityCap.allCases }
        return QualityCap.allCases.filter {
            $0 == .auto || Int($0.maximumResolution.height) <= maxHeight
        }
    }

    private func loadVariantLadder(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] (data, _, _) in
            guard let data = data,
                let playlist = String(data: data, encoding: .utf8) else { return }
            let caps = VideoPlayerManager.availableCaps(inMasterPlaylist: playlist)
            DispatchQueue.main.async {
                self?.availableCaps = caps
                self?.onAvailableCapsChange?()
            }
        }.resume()
    }

    private func observeRate() {
        rateObserver = player.observe(\.rate, options: [.initial, .new]) { [weak self] player, _ in
            let isPaused = player.rate == 0
            DispatchQueue.main.async {
                self?.onPauseStateChange?(isPaused)
            }
        }
    }

    func startPlaying() {
        player.play()
        guard let duration = player.currentItem?.asset.duration,
            progress != 0.0 else { return }
        let durationInSecs = CMTimeGetSeconds(duration)
        let timeOffset = durationInSecs * progress
        player.seek(to: CMTimeMakeWithSeconds(timeOffset, preferredTimescale: 1))
    }

    func addTimeObserver(period: Int64,
                         block: @escaping (Float64, Float64) -> Void) {
        player.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: period, timescale: 1),
            queue: DispatchQueue.main,
            using: { (time) -> Void in
                let p = CMTimeGetSeconds(time)
                let d: Float64
                if let duration = self.player.currentItem?.asset.duration {
                    d = CMTimeGetSeconds(duration)
                } else {
                    d = 0.0
                }
                block(p, d)
        })
    }

    // MARK: - Private functions
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logDebug("[VideoPlayer] AVAudioSession activation failed")
        }
    }

    /// Explicitly applies an audio track once the item is ready to play.
    ///
    /// AVPlayer's automatic media selection sometimes doesn't reach the audio
    /// renderer (streams that don't flag a default audible rendition, or a race
    /// with item setup), so playback starts silent until a track is picked by
    /// hand. Selecting it explicitly on `.readyToPlay` avoids that.
    private func observePresentationSize(of item: AVPlayerItem) {
        presentationSizeObserver = item.observe(\.presentationSize,
                                                options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.onPresentationSizeChange?(item.presentationSize)
            }
        }
    }

    private func selectAudibleOptionWhenReady(for item: AVPlayerItem) {
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            self?.selectPreferredAudibleOption(for: item)
            self?.itemStatusObserver?.invalidate()
            self?.itemStatusObserver = nil
        }
    }

    private func selectPreferredAudibleOption(for item: AVPlayerItem) {
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
            !group.options.isEmpty else { return }

        let englishOptions = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options,
            with: Locale(identifier: "en")
        )
        guard let option = englishOptions.first ?? group.defaultOption ?? group.options.first else {
            return
        }
        item.select(option, in: group)
    }
}
