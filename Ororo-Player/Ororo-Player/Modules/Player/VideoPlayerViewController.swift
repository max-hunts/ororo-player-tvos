//
//  VideoPlayerViewController.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import AVKit
import OroroKit

final class VideoPlayerViewController: AVPlayerViewController, UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    // MARK: - Properties
    private let subtitleManager: SubtitleManager
    private let videoPlayerManager: VideoPlayerManager

    private let labelSubtitle = UILabel()
    private let qualityBadge = UIButton(type: .custom)
    private var currentResolutionTitle: String?
    private var isPlayerPaused = true
    private var isTransportRecentlyUsed = false
    private var badgeHideWorkItem: DispatchWorkItem?

    // MARK: - Life cycle
    public init(subtitleManager: SubtitleManager,
                videoPlayerManager: VideoPlayerManager) {
        self.subtitleManager = subtitleManager
        self.videoPlayerManager = videoPlayerManager
        super.init(nibName: nil, bundle: nil)
        player = videoPlayerManager.player
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Initializer is not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSubtitleLabel()
        configureObserver()
        configureQualityControls()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        videoPlayerManager.startPlaying()
    }

    // MARK: - Private functions
    private func configureObserver() {
        videoPlayerManager.addTimeObserver(period: 1) { [weak self] (progress, _) in
            guard let self = self else { return }
            self.subtitleManager.configure(
                label: self.labelSubtitle,
                time: progress
            )
        }
    }

    /// A small badge in the top-right corner shows the resolution currently
    /// playing; it follows AVPlayer's variant switches. On iOS tapping it
    /// opens the quality picker; on tvOS the picker lives in the transport
    /// bar menu (tvOS 15+) and the badge is display-only.
    private func configureQualityControls() {
        qualityBadge.setTitleColor(.white, for: .normal)
        qualityBadge.backgroundColor = UIColor(white: 0, alpha: 0.6)
        qualityBadge.clipsToBounds = true
        qualityBadge.isHidden = true

        qualityBadge.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        qualityBadge.layer.cornerRadius = 6
        qualityBadge.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        qualityBadge.isUserInteractionEnabled = false
        configureQualityMenu()

        contentOverlayView?.addSubview(qualityBadge)
        qualityBadge.layout(builder: {
            $0.top <-> 60
            $0.trailing <-> (self.contentOverlayView!.trailing + (-90))
        })

        videoPlayerManager.onPresentationSizeChange = { [weak self] size in
            self?.currentResolutionTitle = VideoPlayerViewController.resolutionTitle(for: size)
            self?.updateQualityBadgeVisibility()
        }
        // The badge only accompanies the playback controls: pausing summons
        // them, and so does touching the remote/screen. There is no public
        // "controls visible" API, so remote contact is detected with a
        // non-consuming recognizer and the badge auto-hides after roughly the
        // transport overlay's own timeout.
        videoPlayerManager.onPauseStateChange = { [weak self] isPaused in
            self?.isPlayerPaused = isPaused
            // Resuming with the play/pause button also summons the overlay,
            // without any touch contact; let the badge track it.
            if !isPaused {
                self?.revealQualityBadgeTemporarily()
            }
            self?.updateQualityBadgeVisibility()
        }

        let interaction = UILongPressGestureRecognizer(
            target: self,
            action: #selector(userDidInteract)
        )
        interaction.minimumPressDuration = 0
        interaction.cancelsTouchesInView = false
        // The player's own recognizers win the gesture arena and would
        // silently suppress this one without simultaneous recognition.
        interaction.delegate = self
        interaction.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.indirect.rawValue)
        ]
        view.addGestureRecognizer(interaction)
        videoPlayerManager.onAvailableCapsChange = { [weak self] in
            self?.configureQualityMenu()
        }
    }

    private func updateQualityBadgeVisibility() {
        guard let title = currentResolutionTitle,
            isPlayerPaused || isTransportRecentlyUsed else {
            qualityBadge.isHidden = true
            return
        }
        qualityBadge.isHidden = false
        qualityBadge.setTitle(title, for: .normal)
        // 4K playback earns a gold badge.
        let titleColor: UIColor = title == "4K" ? .init(rgb: 0xFFD700) : .white
        qualityBadge.setTitleColor(titleColor, for: .normal)
    }

    @objc private func userDidInteract(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began else { return }
        revealQualityBadgeTemporarily()
    }

    private func revealQualityBadgeTemporarily() {
        isTransportRecentlyUsed = true
        updateQualityBadgeVisibility()

        badgeHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.isTransportRecentlyUsed = false
            self?.updateQualityBadgeVisibility()
        }
        badgeHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    /// Classifies by width: letterboxed encodes (e.g. 1920x800) keep their
    /// class's width while the height shrinks.
    private static func resolutionTitle(for size: CGSize) -> String? {
        guard size != .zero else { return nil }
        switch size.width {
        case 3000...: return "4K"
        case 2300...: return "1440p"
        case 1600...: return "1080p"
        case 1100...: return "720p"
        case 700...: return "480p"
        case 500...: return "360p"
        case _: return "240p"
        }
    }

    private func configureQualityMenu() {
        if #available(tvOS 15.0, *) {
            transportBarCustomMenuItems = [makeQualityMenu()]
        }
    }

    @available(tvOS 15.0, *)
    private func makeQualityMenu() -> UIMenu {
        let actions = videoPlayerManager.availableCaps.map { cap in
            UIAction(
                title: cap.title,
                state: cap == videoPlayerManager.effectiveCap ? .on : .off,
                handler: { [weak self] _ in
                    self?.videoPlayerManager.apply(cap)
                    // Rebuild so the checkmark follows the selection.
                    self?.configureQualityMenu()
                }
            )
        }
        return UIMenu(
            title: "quality".localized(),
            image: UIImage(systemName: "slider.horizontal.3"),
            children: actions
        )
    }

    private func configureSubtitleLabel() {
        labelSubtitle.backgroundColor = UIColor.clear
        labelSubtitle.textAlignment = .center
        labelSubtitle.font = DeviceVisualTheme.subtitleFont
        labelSubtitle.textColor = UIColor.white
        labelSubtitle.numberOfLines = 0
        labelSubtitle.layer.shadowColor = UIColor.black.cgColor
        labelSubtitle.layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        labelSubtitle.layer.shadowOpacity = 0.9
        labelSubtitle.layer.shadowRadius = 1.0
        labelSubtitle.layer.shouldRasterize = true
        labelSubtitle.layer.rasterizationScale = UIScreen.main.scale
        labelSubtitle.lineBreakMode = .byWordWrapping
        contentOverlayView?.addSubview(labelSubtitle)

        labelSubtitle.layout(builder: {
            $0.bottom <-> -50
            $0.centerX <-> self.contentOverlayView!.centerX
            $0.leading <-> (self.contentOverlayView!.leading + 30)
            $0.trailing <-> (self.contentOverlayView!.trailing + (-30))
        })
    }
}
