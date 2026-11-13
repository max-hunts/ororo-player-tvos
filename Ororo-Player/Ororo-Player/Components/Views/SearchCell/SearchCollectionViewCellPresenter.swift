//
//  SearchCollectionViewCellPresenter.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit

final class SearchCollectionViewCellPresenter: CollectionViewCellPresenter {

    typealias CellType = SearchCollectionViewCell
    typealias ModelType = Searchable

    static func configure(cell: CellType,
                          model: ModelType) {
        cell.labelName.text = model.title
        cell.setProgress(model.playbackProgress)
        if let urlString = model.posterThumb,
            let url = URL(string: urlString) {
            cell.setPoster(url: url)
        }
    }

    static func sizeForCell(maximumWidth width: CGFloat) -> CGSize {
        return DeviceVisualTheme.sizeForSearchCell(maxWidth: width)
    }
}
