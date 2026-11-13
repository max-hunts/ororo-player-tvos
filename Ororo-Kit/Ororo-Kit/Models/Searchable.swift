//
//  Searchable.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit

public protocol DecoratedSearchable {
    var id: Int { get }
    var title: String { get }
    var desc: String? { get }
    var posterThumb: String? { get }
    var playbackProgress: Double? { get }
}

/// Catalog metadata shared by movies and shows, used for sorting and genre
/// filtering. Fields absent from a model's API payload default to nil.
public protocol CatalogSortable {
    var imdbRating: Double? { get }
    var year: String? { get }
    var userPopularity: Int? { get }
    var updatedAt: Double? { get }
    var newestVideo: Double? { get }
    var genres: [String]? { get }
}

public extension CatalogSortable {
    var userPopularity: Int? { return nil }
    var newestVideo: Double? { return nil }
}

public extension DecoratedSearchable {
    var desc: String? { return "" }
    var playbackProgress: Double? { return 0.0 }
}

public struct Searchable: DecoratedSearchable {

    public let model: DecoratedSearchable

    public init(model: DecoratedSearchable) {
        self.model = model
    }
}

extension Searchable: Uniqueable {

    public var id: Int {
        // Use bitwise NOT for shows to create a disjoint ID space from movies,
        // avoiding collisions when movies and shows share the same numeric server ID.
        // Swift's hashValue is non-deterministic per launch, so we use a stable approach.
        return model is Movie ? model.id : ~model.id
    }

    public var title: String {
        return model.title
    }

    public var posterThumb: String? {
        return model.posterThumb
    }

    public static func == (lhs: Searchable, rhs: Searchable) -> Bool {
        return lhs.id == rhs.id
    }
}
