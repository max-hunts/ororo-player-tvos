//
//  SearchCollectionViewCell.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit

final class SearchCollectionViewCell: UICollectionViewCell {

    // MARK: - Constants
    /// Height reserved below the poster for the title label.
    static let titleAreaHeight: CGFloat = 80
    private static let posterCornerRadius: CGFloat = 16
    private static let focusedScale: CGFloat = 1.1
    private static let progressBarHeight: CGFloat = 8
    private static let progressBarMargin: CGFloat = 20

    // MARK: - Properties
    let labelProgress = UILabel()
    let labelName = UILabel()
    let imageViewCover = UIImageView()
    let background = UIView()

    private let shadowView = UIView()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressFraction: CGFloat = 0

    // MARK: - Life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageViewCover.stopLoading()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext,
                                 with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Scale anchored to the bottom edge so the grown poster
                // expands upward and never covers the title below it.
                let lift = self.imageViewCover.bounds.height * (Self.focusedScale - 1) / 2
                let scale = CGAffineTransform(translationX: 0, y: -lift)
                    .scaledBy(x: Self.focusedScale, y: Self.focusedScale)
                self.imageViewCover.transform = scale
                self.shadowView.transform = scale
                self.shadowView.layer.shadowOpacity = 0.45
                self.labelName.textColor = .white
            } else {
                self.imageViewCover.transform = .identity
                self.shadowView.transform = .identity
                self.shadowView.layer.shadowOpacity = 0
                self.labelName.textColor = UIColor(white: 1, alpha: 0.7)
            }
        }, completion: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.layer.shadowPath = UIBezierPath(
            roundedRect: shadowView.bounds,
            cornerRadius: Self.posterCornerRadius
        ).cgPath
        layoutProgressBar()
    }

    // MARK: - Public interface
    func setPoster(url: URL) {
        // Sized for a ~340pt-wide poster tile at 2x; also forces the JPEG
        // decode off the main thread so scrolling doesn't drop frames.
        imageViewCover.set(url: url, maxPixelSize: 1000)
    }

    func setProgress(_ fraction: Double?) {
        let progress = fraction ?? 0
        progressFraction = CGFloat(min(max(progress, 0), 1))
        progressTrack.isHidden = progressFraction == 0
        setNeedsLayout()
    }

    // MARK: - Private functions
    private func setupUI() {
        setupUItvOS()
    }

    private func setupUItvOS() {
        // Let the focused poster scale outside the cell bounds.
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear

        labelName.textColor = UIColor(white: 1, alpha: 0.7)
        labelName.textAlignment = .center
        labelName.numberOfLines = 2
        labelName.font = UIFont.systemFont(ofSize: 26,
                                           weight: .medium)

        contentView.addSubview(shadowView)
        contentView.addSubview(imageViewCover)
        contentView.addSubview(labelName)

        // Hand-rolled focus treatment (scale + shadow in didUpdateFocus)
        // instead of adjustsImageWhenAncestorFocused: the system's floating
        // focused appearance renders the poster with square corners, which
        // clashes with the rounded resting state.
        imageViewCover.clipsToBounds = true
        imageViewCover.contentMode = .scaleAspectFill
        imageViewCover.layer.cornerRadius = Self.posterCornerRadius
        if #available(tvOS 13.0, *) {
            imageViewCover.layer.cornerCurve = .continuous
        }

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 12)
        shadowView.layer.shadowRadius = 24
        shadowView.layer.shadowOpacity = 0

        progressTrack.backgroundColor = UIColor(white: 1, alpha: 0.3)
        progressTrack.layer.cornerRadius = Self.progressBarHeight / 2
        progressTrack.clipsToBounds = true
        progressTrack.isHidden = true
        progressFill.backgroundColor = .white
        progressTrack.addSubview(progressFill)
        imageViewCover.addSubview(progressTrack)

        imageViewCover.layout {
            $0.top <-> 0
            $0.leading <-> 0
            $0.trailing <-> 0
            $0.bottom <-> -Self.titleAreaHeight
        }
        shadowView.layout {
            $0.top <-> 0
            $0.leading <-> 0
            $0.trailing <-> 0
            $0.bottom <-> -Self.titleAreaHeight
        }
        labelName.layout {
            $0.top <-> (imageViewCover.bottom + 14)
            $0.leading <-> 0
            $0.trailing <-> 0
        }
    }

    private func layoutProgressBar() {
        let bounds = imageViewCover.bounds
        let trackWidth = bounds.width - Self.progressBarMargin * 2
        progressTrack.frame = CGRect(x: Self.progressBarMargin,
                                     y: bounds.height - Self.progressBarMargin - Self.progressBarHeight,
                                     width: trackWidth,
                                     height: Self.progressBarHeight)
        progressFill.frame = CGRect(x: 0,
                                    y: 0,
                                    width: trackWidth * progressFraction,
                                    height: Self.progressBarHeight)
    }
}
