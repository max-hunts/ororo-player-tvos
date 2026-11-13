//
//  OpenMoviesFlow.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit
import Transitions

final class OpenMoviesFlow: Flow {

    struct Injection {
        let items: [Searchable]
        let serviceProvider: ServiceProvider
    }

    // MARK: - Flow
    let coordinator: Coordinator
    unowned var serviceProvider: ServiceProvider!

    private var browsing: CatalogBrowsing!
    private weak var moviesViewController: SearchViewController?

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
        ) {

        serviceProvider = injection.serviceProvider
        browsing = CatalogBrowsing(
            items: injection.items,
            sortOptions: CatalogSortOption.moviesOptions,
            defaultSort: .recentlyAdded,
            sortStorageKey: "movies.sortOption"
        )

        let moviesController = SearchViewController(output: self)
        moviesController.title = "movies".localized()
        moviesController.configure(with: browsing.visibleItems)
        moviesController.onSortPress = { [weak self] in
            self?.pickSort()
        }
        moviesController.onGenrePress = { [weak self] in
            self?.pickGenre()
        }
        self.moviesViewController = moviesController
        updateControls()

        let navigationController = UINavigationController(
            rootViewController: moviesController
        )

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.inTabBar,
            params: (
                navigationController,
                UIImage(named: "movies.tabbar.icon")
            )
        )
    }

    // MARK: - Sorting & filtering

    private func pickSort() {
        guard let viewController = moviesViewController else { return }
        browsing.presentSortPicker(from: viewController) { [weak self] in
            self?.refresh()
        }
    }

    private func pickGenre() {
        guard let viewController = moviesViewController else { return }
        browsing.presentGenrePicker(from: viewController) { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        moviesViewController?.reload(with: browsing.visibleItems)
        updateControls()
    }

    private func updateControls() {
        moviesViewController?.updateSortControl(title: browsing.sortControlTitle)
        moviesViewController?.updateGenreControl(title: browsing.genreControlTitle)
    }
}

extension OpenMoviesFlow: SearchViewOutput {

    func didPressLong(model: Searchable) {
        guard let movie = model.model as? Movie else { return }
        coordinator.show(
            OpenMovieFlow.self,
            injection: OpenMovieFlow.Injection(
                movie: movie,
                serviceProvider: serviceProvider,
                isLongPressed: true
            )
        )
    }

    func didPress(model: Searchable) {
        guard let movie = model.model as? Movie else { return }
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
