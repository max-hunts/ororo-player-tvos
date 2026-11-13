//
//  Show.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import Foundation
import CoreData

public struct Shows: Codable {
    public let shows: [Show]?
}

public struct Show: Codable, DecoratedSearchable {

    public let id: Int
    public let name: String
    public let desc: String?
    public let episodes: [Episode]?
    public let posterThumb: String?
    public let isFavourite: Bool?
    public let imdbRating: Double?
    public let year: String?
    public let userPopularity: Int?
    public let updatedAt: Double?
    public let newestVideo: Double?
    public let genres: [String]?

    // MARK: - Searchable
    public var title: String {
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, desc, episodes, isFavourite, year
        case posterThumb = "poster_thumb"
        case imdbRating = "imdb_rating"
        case userPopularity = "user_popularity"
        case updatedAt = "updated_at"
        case newestVideo = "newest_video"
        case genres = "array_genres"
    }
}

extension Show: CatalogSortable {}

@objc(CDShow)
final public class CDShow: NSManagedObject {
    @NSManaged var id: Int
    @NSManaged var name: String
    @NSManaged var desc: String
    @NSManaged var episodes: Set<CDEpisode>?
    @NSManaged var posterThumb: String
    @NSManaged public var isFavourite: NSNumber
    @NSManaged var imdbRating: Double
    @NSManaged var year: String
    @NSManaged var userPopularity: Int
    @NSManaged var updatedAt: Double
    @NSManaged var newestVideo: Double
    @NSManaged var genres: String
}

extension Show {
    public init(show: CDShow) {
        self.id = show.id
        self.name = show.name
        self.desc = show.desc
        self.episodes = show.episodes?.map { Episode(episode: $0) }
        self.posterThumb = show.posterThumb
        self.isFavourite = show.isFavourite.boolValue
        self.imdbRating = show.imdbRating
        self.year = show.year
        self.userPopularity = show.userPopularity
        self.updatedAt = show.updatedAt
        self.newestVideo = show.newestVideo
        self.genres = show.genres.isEmpty ? nil : show.genres.components(separatedBy: ",")
    }
}

extension CDShow {
    func configure(with show: Show) {
        self.id = show.id
        self.name = show.name
        self.desc = show.desc ?? ""
        self.posterThumb = show.posterThumb ?? ""

        // Sort metadata may be absent from some API payloads; never
        // overwrite previously cached values with defaults.
        if let imdbRating = show.imdbRating { self.imdbRating = imdbRating }
        if let year = show.year { self.year = year }
        if let userPopularity = show.userPopularity { self.userPopularity = userPopularity }
        if let updatedAt = show.updatedAt { self.updatedAt = updatedAt }
        if let newestVideo = show.newestVideo { self.newestVideo = newestVideo }
        if let genres = show.genres { self.genres = genres.joined(separator: ",") }

        let episodes = show.episodes?.map { (ep) -> CDEpisode in
            let episode = CDEpisode.forceCreate(with: "\(ep.id)",
                                                  into: managedObjectContext!) as CDEpisode
            episode.configure(with: ep)
            return episode
        }

        if let episodes = episodes {
            self.episodes = Set(episodes)
        }
    }
}
