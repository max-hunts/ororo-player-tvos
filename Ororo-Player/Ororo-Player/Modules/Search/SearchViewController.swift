//
//  SearchViewController.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit

protocol SearchViewOutput {
    func didPress(model: Searchable)
    func didPressLong(model: Searchable)
}

class SearchViewController: BaseViewController<SearchCollectionViewCellPresenter>,
UISearchControllerDelegate, UISearchResultsUpdating {

    // MARK: - Properties
    private let output: SearchViewOutput
    var onSortPress: (() -> Void)?
    var onGenrePress: (() -> Void)?
    private var sortButton: UIButton?
    private var genreButton: UIButton?
    private var headerStack: UIStackView?

    // MARK: - Life cycle
    init(output: SearchViewOutput) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tap = { [unowned self] searchable in
            self.output.didPress(model: searchable)
        }

        longTap = { [unowned self] searchable in
            self.output.didPressLong(model: searchable)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dataSource.filter { $0 }
    }

    // MARK: - Sorting & filtering
    /// Installs the sort control on first call and keeps its title in sync
    /// with the selected option. Screens that never call this get no sort UI.
    func updateSortControl(title: String) {
        if sortButton == nil {
            let button = makeHeaderButton(action: #selector(sortPressed))
            ensureHeaderStack().addArrangedSubview(button)
            sortButton = button
        }
        sortButton?.setTitle(title, for: .normal)
    }

    /// Same contract as `updateSortControl`, for the genre filter. The genre
    /// control always sits left of the sort control.
    func updateGenreControl(title: String) {
        if genreButton == nil {
            let button = makeHeaderButton(action: #selector(genrePressed))
            ensureHeaderStack().insertArrangedSubview(button, at: 0)
            genreButton = button
        }
        genreButton?.setTitle(title, for: .normal)
    }

    @objc private func sortPressed() {
        onSortPress?()
    }

    @objc private func genrePressed() {
        onGenrePress?()
    }

    private func makeHeaderButton(action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: DeviceVisualTheme.descriptionFontSize,
            weight: .medium
        )
        button.addTarget(self, action: action, for: .primaryActionTriggered)
        return button
    }

    /// The controls live in a grid header rather than floating over the
    /// collection view, so they scroll away with the first row instead of
    /// overlaying poster titles.
    private func ensureHeaderStack() -> UIStackView {
        if let headerStack = headerStack {
            return headerStack
        }
        let container = UIView()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 60
        container.addSubview(stack)
        stack.layout {
            $0.trailing <-> -40
            $0.centerY <-> 0
        }
        dataSource.headerView = container
        dataSource.headerHeight = 80
        headerStack = stack
        return stack
    }

    // MARK: - UISearchResultsUpdating
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        if text.isEmpty {
            dataSource.filter { $0 }
        } else {
            dataSource.filter { (items) -> [Searchable] in
                return items.filter { $0.title.lowercased().contains(text.lowercased()) }
            }
        }
    }
}
