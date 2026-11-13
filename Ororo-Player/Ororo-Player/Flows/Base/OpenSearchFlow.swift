//
//  OpenSearchFlow.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit
import Transitions

final class OpenSearchFlow: Flow {

    struct Injection {
        let movies: [Searchable]
        let shows: [Searchable]
        let serviceProvider: ServiceProvider
    }

    let coordinator: Coordinator
    unowned var serviceProvider: ServiceProvider!

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
        ) {
        serviceProvider = injection.serviceProvider

        let searchViewController = SearchViewController(output: self)
        let content = (injection.movies + injection.shows)
            .sorted { $0.title < $1.title }

        searchViewController.configure(with: content)

        let viewController = getSearchController(
            searchViewController: searchViewController
        )

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.inTabBar,
            params: (
                viewController,
                UIImage(named: "search.tabbar.icon")
            )
        )
    }

    // MARK: - Private functions

    private func getSearchController(
        searchViewController: SearchViewController
        ) -> UINavigationController {
        let searchController = UISearchController(
            searchResultsController: searchViewController
        )
        searchController.searchResultsUpdater = searchViewController
        searchController.title = "search".localized()
        searchController.searchBar.placeholder = "search_placeholder".localized()
        // Keep the system search UI's material look; a solid color here
        // paints a flat box over the whole screen.
        searchController.view.backgroundColor = .clear
        searchController.searchBar.keyboardAppearance = .dark
        if #available(tvOS 14.0, *) {
            // Full-screen results: lets the search bar/keyboard scroll away
            // with the results instead of staying fixed over them.
            searchController.searchControllerObservedScrollView =
                searchViewController.collectionView
        }

        let searchContainerViewController = UISearchContainerViewController(
            searchController: searchController
        )
        searchContainerViewController.title = "search".localized()
        searchContainerViewController.view.backgroundColor = DeviceVisualTheme.backgroundColor

        if #available(tvOS 13.0, *) {
            // Pin the tab bar fully on screen in the search tab. Left alone,
            // it tracks the search UI's internal scroll view and comes to rest
            // half off the top edge. A stand-in that never scrolls keeps it put.
            searchContainerViewController.tabBarObservedScrollView = UIScrollView()
        }

        let searchNavController = UINavigationController(
            rootViewController: searchContainerViewController
        )
        // The redundant "Search" bar would scroll half-off screen above the keyboard.
        searchNavController.setNavigationBarHidden(true, animated: false)
        return searchNavController
    }
}

extension OpenSearchFlow: SearchViewOutput {

    func didPressLong(model: Searchable) {
        if let show = model.model as? Show {
            coordinator.show(
                OpenShowFlow.self,
                injection: OpenShowFlow.Injection(
                    show: show,
                    serviceProvider: serviceProvider,
                    comletion: nil,
                    isLongPressed: true
                )
            )
        } else if let movie = model.model as? Movie {
            coordinator.show(
                OpenMovieFlow.self,
                injection: OpenMovieFlow.Injection(
                    movie: movie,
                    serviceProvider: serviceProvider,
                    isLongPressed: true
                )
            )
        }
    }

    func didPress(model: Searchable) {
        if let show = model.model as? Show {
            coordinator.show(
                OpenShowFlow.self,
                injection: OpenShowFlow.Injection(
                    show: show,
                    serviceProvider: serviceProvider,
                    comletion: nil,
                    isLongPressed: false
                )
            )
        } else if let movie = model.model as? Movie {
            coordinator.show(
                OpenMovieFlow.self,
                injection: OpenMovieFlow.Injection(
                    movie: movie,
                    serviceProvider: serviceProvider,
                    isLongPressed: false
                )
            )
        }
    }
}
