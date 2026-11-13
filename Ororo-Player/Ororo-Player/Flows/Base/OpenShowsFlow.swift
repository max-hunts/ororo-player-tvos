//
//  OpenShowsFlow.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit
import Transitions

/// Sort options mirroring the ororo.tv website. The API delivers the full
/// catalog in one response, so sorting is done locally. Shared by the Shows
/// and Movies tabs; each tab offers the subset its API payload supports.
enum CatalogSortOption: String, CaseIterable {

    case popularity
    case rating
    case name
    case year
    case updateDate
    case publicationDate
    case recentlyAdded

    static let showsOptions: [CatalogSortOption] = [
        .popularity, .rating, .name, .year, .updateDate, .publicationDate
    ]

    // The movies payload carries no popularity or publication timestamp.
    static let moviesOptions: [CatalogSortOption] = [
        .rating, .name, .year, .updateDate, .recentlyAdded
    ]

    var title: String {
        switch self {
        case .popularity: return "sort_popularity".localized()
        case .rating: return "sort_rating".localized()
        case .name: return "sort_name".localized()
        case .year: return "sort_year".localized()
        case .updateDate: return "sort_update_date".localized()
        case .publicationDate: return "sort_publication_date".localized()
        case .recentlyAdded: return "sort_recently_added".localized()
        }
    }

    func sorted(_ items: [Searchable]) -> [Searchable] {
        switch self {
        case .popularity:
            return sortedDescending(items) { $0?.userPopularity ?? 0 }
        case .rating:
            return sortedDescending(items) { $0?.imdbRating ?? 0 }
        case .name:
            return items.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .year:
            return sortedDescending(items) { $0?.year ?? "" }
        case .updateDate:
            return sortedDescending(items) { $0?.updatedAt ?? 0 }
        case .publicationDate:
            return sortedDescending(items) { $0?.newestVideo ?? 0 }
        case .recentlyAdded:
            // Falls straight through to the id tie-breaker.
            return sortedDescending(items) { _ in 0 }
        }
    }

    private func sortedDescending<Value: Comparable>(
        _ items: [Searchable],
        by value: (CatalogSortable?) -> Value
        ) -> [Searchable] {
        return items.sorted {
            let lhs = value($0.model as? CatalogSortable)
            let rhs = value($1.model as? CatalogSortable)
            if lhs != rhs { return lhs > rhs }
            // Tie-breaker: most recently added first. Sort on the underlying
            // model id (Searchable.id applies a bitwise-NOT to shows, which
            // would invert the order).
            return $0.model.id > $1.model.id
        }
    }
}

/// Sort + genre state for a catalog tab, including the pickers that change
/// it. The sort choice persists per tab; the genre filter is session-only.
final class CatalogBrowsing {

    private let items: [Searchable]
    private let sortOptions: [CatalogSortOption]
    private let sortStorageKey: String
    private(set) var sortOption: CatalogSortOption
    private(set) var genre: String?

    private lazy var allGenres: [String] = {
        var genres = Set<String>()
        for item in items {
            (item.model as? CatalogSortable)?.genres?.forEach { genres.insert($0) }
        }
        return genres.sorted()
    }()

    init(items: [Searchable],
         sortOptions: [CatalogSortOption],
         defaultSort: CatalogSortOption,
         sortStorageKey: String) {
        self.items = items
        self.sortOptions = sortOptions
        self.sortStorageKey = sortStorageKey
        if let raw = UserDefaults.standard.string(forKey: sortStorageKey),
            let restored = CatalogSortOption(rawValue: raw),
            sortOptions.contains(restored) {
            sortOption = restored
        } else {
            sortOption = defaultSort
        }
    }

    var visibleItems: [Searchable] {
        var visible = items
        if let genre = genre {
            visible = visible.filter {
                ($0.model as? CatalogSortable)?.genres?.contains(genre) ?? false
            }
        }
        return sortOption.sorted(visible)
    }

    var sortControlTitle: String {
        return "sort_by".localized() + ": " + sortOption.title
    }

    var genreControlTitle: String {
        return "genre".localized() + ": " + (genre ?? "all_genres".localized())
    }

    func presentSortPicker(from viewController: SearchViewController,
                           onChange: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "sort_by".localized(),
            message: nil,
            preferredStyle: .actionSheet
        )
        for option in sortOptions {
            let checkmark = option == sortOption ? "✓ " : ""
            alert.addAction(UIAlertAction(
                title: checkmark + option.title,
                style: .default,
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.sortOption = option
                    UserDefaults.standard.set(option.rawValue, forKey: self.sortStorageKey)
                    onChange()
                }
            ))
        }
        alert.addAction(UIAlertAction(
            title: "cancel".localized(),
            style: .cancel,
            handler: nil
        ))
        viewController.present(alert, animated: true, completion: nil)
    }

    func presentGenrePicker(from viewController: SearchViewController,
                            onChange: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "genre".localized(),
            message: nil,
            preferredStyle: .actionSheet
        )
        let allCheckmark = genre == nil ? "✓ " : ""
        alert.addAction(UIAlertAction(
            title: allCheckmark + "all_genres".localized(),
            style: .default,
            handler: { [weak self] _ in
                self?.genre = nil
                onChange()
            }
        ))
        for genre in allGenres {
            let checkmark = genre == self.genre ? "✓ " : ""
            alert.addAction(UIAlertAction(
                title: checkmark + genre,
                style: .default,
                handler: { [weak self] _ in
                    self?.genre = genre
                    onChange()
                }
            ))
        }
        alert.addAction(UIAlertAction(
            title: "cancel".localized(),
            style: .cancel,
            handler: nil
        ))
        viewController.present(alert, animated: true, completion: nil)
    }
}

final class OpenShowsFlow: Flow {

    struct Injection {
        let items: [Searchable]
        let serviceProvider: ServiceProvider
    }

    let coordinator: Coordinator
    unowned var serviceProvider: ServiceProvider!

    private var browsing: CatalogBrowsing!
    private weak var showsViewController: SearchViewController?

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
            sortOptions: CatalogSortOption.showsOptions,
            defaultSort: .popularity,
            sortStorageKey: "shows.sortOption"
        )

        let showsViewController = SearchViewController(output: self)
        showsViewController.title = "shows".localized()
        showsViewController.configure(with: browsing.visibleItems)
        showsViewController.onSortPress = { [weak self] in
            self?.pickSort()
        }
        showsViewController.onGenrePress = { [weak self] in
            self?.pickGenre()
        }
        self.showsViewController = showsViewController
        updateControls()

        let navigationController = UINavigationController(
            rootViewController: showsViewController
        )

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.inTabBar,
            params: (
                navigationController,
                UIImage(named: "series.tabbar.icon")
            )
        )
    }

    // MARK: - Sorting & filtering

    private func pickSort() {
        guard let viewController = showsViewController else { return }
        browsing.presentSortPicker(from: viewController) { [weak self] in
            self?.refresh()
        }
    }

    private func pickGenre() {
        guard let viewController = showsViewController else { return }
        browsing.presentGenrePicker(from: viewController) { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        showsViewController?.reload(with: browsing.visibleItems)
        updateControls()
    }

    private func updateControls() {
        showsViewController?.updateSortControl(title: browsing.sortControlTitle)
        showsViewController?.updateGenreControl(title: browsing.genreControlTitle)
    }
}

extension OpenShowsFlow: SearchViewOutput {
    func didPressLong(model: Searchable) {
        guard let show = model.model as? Show else { return }
        coordinator.show(
            OpenShowFlow.self,
            injection: OpenShowFlow.Injection(
                show: show,
                serviceProvider: serviceProvider,
                comletion: nil,
                isLongPressed: true
            )
        )
    }

    func didPress(model: Searchable) {
        guard let show = model.model as? Show else { return }
        coordinator.show(
            OpenShowFlow.self,
            injection: OpenShowFlow.Injection(
                show: show,
                serviceProvider: serviceProvider,
                comletion: nil,
                isLongPressed: false
            )
        )
    }
}
