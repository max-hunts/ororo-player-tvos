//
//  MoviesDataProvider.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import CoreData
import Foundation

public final class MoviesDataProvider {

    // MARK: - Properties
    private let networkService: NetworkRequestsService
    private let storageService: StorageService

    // MARK: - Life cycle
    public init(networkService: NetworkRequestsService,
                storageService: StorageService) {
        self.networkService = networkService
        self.storageService = storageService
    }

    // MARK: - Public interface
    public func loadMovies(onSuccess: @escaping ([Movie]?) -> Void,
                           onError: @escaping (DataProviderError) -> Void) {

        let movies = storageService.fetchAll() as [CDMovie]?
        let movies_ = movies?.map { Movie(movie: $0) }

        let shouldUpdateOnSuccess = movies_ == nil || movies_!.isEmpty

        if let movies = movies_, !movies.isEmpty {
            onSuccess(movies)
        }

        networkService.request(with: ApiServiceEnpoint.movies,
                               onSuccess: { (movies: Movies) in
                                self.save(movies: movies.movies!)
                                if shouldUpdateOnSuccess {
                                    onSuccess(movies.movies)
                                }
        }, onError: { (error) in
            if !shouldUpdateOnSuccess { return }
            if (error as NSError).code == -1009 {
                logDebug("[DataProvider] The Internet connection appears to be offline.")
                onError(.noNetwork)
            } else {
                logDebug("[DataProvider] Error has occured \(error)")
                onError(.unknown(error))
            }
        })
    }

    public func loadMovie(with id: Int,
                          onSuccess: @escaping (Movie?) -> Void,
                          onError: @escaping (DataProviderError) -> Void) {

        let cached = (storageService.fetchAll("id == %@",
                                              arguments: [id]) as [CDMovie]?)?.first

        // Mirror loadEpisod: a cached movie is only useful for immediate playback if it
        // carries a stream url and subtitles. The listing endpoint omits those, so a
        // cached-but-incomplete movie fails the player's url/subtitles guard on the first
        // tap and only plays on the second (once the detail fetch silently completes the
        // cache). Treat an incomplete cache as a miss so the network detail is delivered.
        let isPlayable = cached?.url != nil && !(cached?.subtitles?.isEmpty ?? true)
        let shouldUpdateOnSuccess = !isPlayable

        if let cached = cached {
            onSuccess(Movie(movie: cached))
        }

        networkService.request(with: ApiServiceEnpoint.movie(id: id),
                               onSuccess: { (movie: Movie) in
                                self.save(movies: [movie])
                                if shouldUpdateOnSuccess {
                                    onSuccess(movie)
                                }
        }, onError: { (error) in
            if !shouldUpdateOnSuccess { return }
            if (error as NSError).code == -1009 {
                logDebug("[DataProvider] The Internet connection appears to be offline.")
                onError(.noNetwork)
            } else {
                logDebug("[DataProvider] Error has occured \(error)")
                onError(.unknown(error))
            }
        })
    }

    // MARK: - Private functions
    private func save(movies: [Movie]) {
        storageService.performAsync(transaction: { (context) in
            // Rewriting ~8000 unchanged rows on every launch is the bulk of
            // launch-time Core Data work, so skip movies whose payload hasn't
            // changed since it was cached. Detail payloads (the ones carrying
            // a stream url) are always written: listing payloads have no url,
            // and writing them would wipe a cached one.
            //
            // Existing rows are looked up through one dictionary rather than
            // forceCreate's per-item fetch: a fetch per row makes the initial
            // full-catalog save quadratic — slow enough on Apple TV hardware
            // that it never finished before the app was quit, leaving only
            // detail-fetched items in the cache.
            let cached = (context.fetchAll() as [CDMovie]?) ?? []
            var cachedById = [Int: CDMovie](minimumCapacity: cached.count)
            cached.forEach { cachedById[$0.id] = $0 }

            for movie in movies {
                let existing = cachedById[movie.id]
                if movie.url == nil,
                    let updatedAt = movie.updatedAt,
                    existing?.updatedAt == updatedAt {
                    continue
                }
                let row: CDMovie
                if let existing = existing {
                    row = existing
                } else {
                    let description = NSEntityDescription.entity(
                        forEntityName: CDMovie.entityName,
                        in: context
                    )!
                    row = CDMovie(entity: description, insertInto: context)
                }
                row.configure(with: movie)
            }
        })
    }
}
