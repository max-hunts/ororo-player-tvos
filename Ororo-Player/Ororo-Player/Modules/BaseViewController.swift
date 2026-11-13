//
//  BaseViewController.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit

extension CollectionViewCellPresenter {

    static func minimumLineSpacingForSection(maximumWidth width: CGFloat) -> CGFloat {
        return DeviceVisualTheme.minimumLineSpacingForSection(maxWidth: width)
    }
}

class BaseViewController<PresenterType>: UIViewController
where PresenterType: CollectionViewCellPresenter {

    // CollectionViewGeneric data source
    let dataSource = GenericCollectionViewDataSource<PresenterType>()

    var tap: ((PresenterType.ModelType) -> Void)?
    var longTap: ((PresenterType.ModelType) -> Void)?
    var viewWillAppear: (() -> Void)?

    var collectionView: UICollectionView!
    var flow: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        DeviceVisualTheme.configureCollectionViewFlow(flow: layout)
        return layout
    }()

    private let loadingLabel = UILabel()
    private let spinner = UIActivityIndicatorView(
        style: DeviceVisualTheme.loaderSpinnerStyle()
    )

    override var title: String? {
        didSet {
            loadingLabel.text = title
        }
    }

    // MARK: - Life cycle
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override init(
        nibName nibNameOrNil: String?,
        bundle nibBundleOrNil: Bundle?
        ) {
        super.init(nibName: nil, bundle: nil)
        loadViewIfNeeded()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        spinner.startAnimating()
        dataSource.configure(
            with: collectionView,
            didPress: { [unowned self] pressedModel in
                self.tap?(pressedModel)
            }
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // No navigation bars on tvOS: a translucent bar title would float
        // over the content while scrolling. The tab bar already names the screen.
        navigationController?.setNavigationBarHidden(true, animated: false)
        self.viewWillAppear?()
    }

    // MARK: - Public interface
    func configure(with items: [PresenterType.ModelType]) {
        spinner.stopAnimating()
        loadingLabel.isHidden = true
        dataSource.update(items: items)
    }

    func reload(with items: [PresenterType.ModelType]) {
        spinner.stopAnimating()
        loadingLabel.isHidden = true
        dataSource.reload(items: items)
        // Scroll to the very top, including the grid header if there is one.
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
    }

    // MARK: - Actions
    @objc
    func handleLongPress(gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let model = dataSource.model(at: indexPath)
            longTap?(model)
        } else {
            logDebug("Couldn't find index path")
        }
    }

    // MARK: - Private functions
    private func setupUI() {
        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: flow
        )

        view.backgroundColor = DeviceVisualTheme.backgroundColor
        view.addSubview(collectionView)
        collectionView.pinToParent()
        collectionView.backgroundColor = DeviceVisualTheme.backgroundColor

        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true

        // Pin the tab bar fully on screen: left to its own devices it tracks
        // the grid's scrolling and comes to rest half cut off at the top edge.
        // A stand-in scroll view that never scrolls keeps it put.
        if #available(tvOS 13.0, *) {
            tabBarObservedScrollView = UIScrollView()
        }

        let longPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress)
        )
//        longPressRecognizer.minimumPressDuration = 1
        collectionView.addGestureRecognizer(longPressRecognizer)

        view.addSubview(spinner)
        spinner.layout {
            $0.centerX <-> view.centerX
            $0.centerY <-> view.centerY
            $0.height <-> 100
            $0.width <-> 100
        }

        loadingLabel.backgroundColor = UIColor.clear
        loadingLabel.textAlignment = .center
        loadingLabel.font = DeviceVisualTheme.titleFont
        loadingLabel.textColor = UIColor.darkGray
        loadingLabel.numberOfLines = 0
        view.addSubview(loadingLabel)
        loadingLabel.layout {
            $0.bottom <-> (spinner.top + 30)
            $0.centerX <-> view.centerX
            $0.height <-> 100
        }
    }
}
