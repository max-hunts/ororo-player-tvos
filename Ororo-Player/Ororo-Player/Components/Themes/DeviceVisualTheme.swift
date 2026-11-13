//
//  DeviceVisualTheme.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit

class DeviceVisualTheme {

    static var titleFontSize: CGFloat {
        return 28
    }

    static var descriptionFontSize: CGFloat {
        return 24
    }

    static var backgroundColor: UIColor {
        // Near-black, content-first background like the native TV app.
        return .init(rgb: 0x141414)
    }

    static var subtitleFont: UIFont {
        return UIFont.boldSystemFont(ofSize: 40.0)
    }

    static var titleFont: UIFont {
        return UIFont.boldSystemFont(ofSize: 56.0)
    }

    static func configureCollectionViewFlow(flow: UICollectionViewFlowLayout) {

        flow.scrollDirection = .vertical
        flow.minimumInteritemSpacing = 40.0
        flow.minimumLineSpacing = 40.0
        flow.sectionInset = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
    }

    static func sizeForSearchCell(maxWidth: CGFloat) -> CGSize {

        // 5 portrait poster tiles per row (2:3, matching the artwork's aspect ratio),
        // plus room for the title below the poster.
        let columns: CGFloat = 5
        let spacing: CGFloat = 40
        let width = (maxWidth - spacing * (columns + 1)) / columns
        let height = width * 3 / 2 + SearchCollectionViewCell.titleAreaHeight
        return CGSize(width: width, height: height)

    }

    static func minimumLineSpacingForSection(maxWidth: CGFloat) -> CGFloat {
        return 150 / 3 - 15
    }

    static func loaderSpinnerStyle() -> UIActivityIndicatorView.Style {
        return .whiteLarge
    }
}
