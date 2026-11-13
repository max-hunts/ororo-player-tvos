//
//  RootFlow.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit
import Transitions

final class RootFlow: Flow {

    // MARK: - Properties
    private let tabBarViewController = UITabBarController()

    // MARK: - Flow
    let coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
        ) {

        let group = DispatchGroup()

        let serviceProvider = injection.serviceProvider
        let credentialsStore = injection.credentialsStore

        var _shows: [Searchable]?
        var _movies: [Searchable]?

        group.enter()
        serviceProvider.showsDataProvider
            .loadAllShows(onSuccess: { (shows) in
                _shows = shows?.map { Searchable(model: $0) }
                group.leave()
            }, onError: { (_) in
                group.leave()
            })

        group.enter()
        serviceProvider.moviesDataProvider
            .loadMovies(onSuccess: { (movies) in
                _movies = movies?.map { Searchable(model: $0) }
                group.leave()
            }, onError: { (_) in
                group.leave()
            })

        group.notify(queue: .main) {
            self.present(
                serviceProvider: serviceProvider,
                credentialsStore: credentialsStore,
                movies: _movies!,
                shows: _shows!
            )
        }

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.root,
            params: tabBarViewController
        )
    }

    // MARK: - Private functions

    private func present(
        serviceProvider: ServiceProvider,
        credentialsStore: CredentialsStore,
        movies: [Searchable],
        shows: [Searchable]
        ) {

        coordinator.show(
            OpenSearchFlow.self,
            injection: OpenSearchFlow.Injection(
                movies: movies,
                shows: shows,
                serviceProvider: serviceProvider
            )
        )

        coordinator.show(
            OpenMoviesFlow.self,
            injection: OpenMoviesFlow.Injection(
                items: movies,
                serviceProvider: serviceProvider
            )
        )

        coordinator.show(
            OpenShowsFlow.self,
            injection: OpenShowsFlow.Injection(
                items: shows,
                serviceProvider: serviceProvider
            )
        )

        coordinator.show(
            OpenFavoritesFlow.self,
            injection: serviceProvider
        )

        coordinator.show(
            OpenSettingsFlow.self,
            injection: OpenSettingsFlow.Injection(
                username: credentialsStore.load()?.username ?? "",
                onLogout: { [weak self] in
                    guard let self = self else { return }
                    serviceProvider.storageService.clearAllData()
                    credentialsStore.clear()
                    self.coordinator.show(
                        LoginFlow.self,
                        injection: LoginFlow.Injection(
                            credentialsStore: credentialsStore,
                            onSuccess: { credentials in
                                self.coordinator.show(
                                    RootFlow.self,
                                    injection: RootFlow.Injection(
                                        serviceProvider: ServiceProvider(credentials: credentials),
                                        credentialsStore: credentialsStore
                                    )
                                )
                            }
                        )
                    )
                }
            )
        )
    }

    // MARK: - Inner type
    struct Injection {
        let serviceProvider: ServiceProvider
        let credentialsStore: CredentialsStore
    }
}
