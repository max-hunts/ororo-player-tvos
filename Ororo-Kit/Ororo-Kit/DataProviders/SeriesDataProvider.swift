//
//  SeriesDataProvider.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import CoreData
import Foundation

public final class SeriesDataProvider {

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
    public func loadAllShows(onSuccess: @escaping ([Show]?) -> Void,
                             onError: @escaping (DataProviderError) -> Void) {

        let shows = storageService.fetchAll() as [CDShow]?
        let shows_ = shows?.map { Show(show: $0) }

        let shouldUpdateOnSuccess = shows_ == nil || shows_!.isEmpty

        if let shows = shows_, !shows.isEmpty {
            onSuccess(shows)
        }

        networkService.request(with: ApiServiceEnpoint.shows,
                               onSuccess: { (shows: Shows) in
                                self.save(shows: shows.shows!)
                                if shouldUpdateOnSuccess {
                                    onSuccess(shows.shows)
                                }
        }, onError: { (error) in
            if shouldUpdateOnSuccess { return }
            if (error as NSError).code == -1009 {
                logDebug("[DataProvider] The Internet connection appears to be offline.")
                onError(.noNetwork)
            } else {
                logDebug("[DataProvider] Error has occured \(error)")
                onError(.unknown(error))
            }
        })
    }

    public func loadShow(showId: Int,
                         onSuccess: @escaping (Show?) -> Void,
                         onError: @escaping (DataProviderError) -> Void) {

        let show: CDShow? = storageService.fetchOne("id == %@", arguments: [showId])

        if let show = show {
            onSuccess(Show(show: show))
        }

        networkService.request(with: ApiServiceEnpoint.show(id: showId),
                               onSuccess: { (show: Show) in
                                onSuccess(show)
                                self.save(shows: [show])
        }, onError: { (error) in
            if (error as NSError).code == -1009 {
                logDebug("[DataProvider] The Internet connection appears to be offline.")
                onError(.noNetwork)
            } else {
                logDebug("[DataProvider] Error has occured \(error)")
                onError(.unknown(error))
            }
        })
    }

    public func loadEpisod(episodId: Int,
                           onSuccess: @escaping (Episode?) -> Void,
                           onError: @escaping (DataProviderError) -> Void) {

        let cached = (storageService.fetchAll("id == %@",
                                              arguments: [episodId]) as [CDEpisode]?)?.first

        // The cached episode is only useful for playback if it carries a stream url
        // and subtitles. A cached-but-incomplete episode would otherwise satisfy the
        // cache hit, fail the player's url/subtitles guard, and only start playing on
        // a second tap once the network response silently completed the cache. Treat
        // an incomplete cache as a miss so the network result is delivered instead.
        let isPlayable = cached?.url != nil && !(cached?.subtitles?.isEmpty ?? true)
        let shouldUpdateOnSuccess = !isPlayable

        if let cached = cached {
            onSuccess(Episode(episode: cached))
        }

        networkService.request(with: ApiServiceEnpoint.episod(id: episodId),
                               onSuccess: { (episode: Episode) in
                                if shouldUpdateOnSuccess {
                                    onSuccess(episode)
                                }
                                self.save(episode: episode)
        }, onError: { (error) in
            if !shouldUpdateOnSuccess { return }
            let code = (error as NSError).code
            if code == -1009 {
                logDebug("[DataProvider] The Internet connection appears to be offline.")
                onError(.noNetwork)
            } else {
                logDebug("[DataProvider] Error has occured \(error)")
                onError(.unknown(error))
            }
        })
    }

    // MARK: - Private functions

    private func save(shows: [Show]) {
        storageService.performAsync(transaction: { (context) in
            // Rewriting ~4000 unchanged rows on every launch is the bulk of
            // launch-time Core Data work, so skip shows whose payload hasn't
            // changed since it was cached. Detail payloads (the ones carrying
            // episodes) are always written: the episodes relationship is only
            // populated through them.
            //
            // Existing rows are looked up through one dictionary rather than
            // forceCreate's per-item fetch: a fetch per row makes the initial
            // full-catalog save quadratic and painfully slow on device.
            let cached = (context.fetchAll() as [CDShow]?) ?? []
            var cachedById = [Int: CDShow](minimumCapacity: cached.count)
            cached.forEach { cachedById[$0.id] = $0 }

            for show in shows {
                let existing = cachedById[show.id]
                if show.episodes == nil,
                    let updatedAt = show.updatedAt,
                    existing?.updatedAt == updatedAt {
                    continue
                }
                let row: CDShow
                if let existing = existing {
                    row = existing
                } else {
                    let description = NSEntityDescription.entity(
                        forEntityName: CDShow.entityName,
                        in: context
                    )!
                    row = CDShow(entity: description, insertInto: context)
                }
                row.configure(with: show)
            }
        })
    }

    private func save(episode: Episode) {
        storageService.performAsync(transaction: { (context) in
            if let fetchedEpisode = context.fetchOne("id == %@", arguments: [episode.id]) as CDEpisode? {
                fetchedEpisode.configure(with: episode)
            } else {
                let createdEpisode = CDEpisode.forceCreate(with: "\(episode.id)", into: context) as CDEpisode
                createdEpisode.configure(with: episode)
            }
        })
    }
}
