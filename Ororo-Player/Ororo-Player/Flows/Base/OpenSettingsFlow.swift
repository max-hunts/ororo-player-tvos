//
//  OpenSettingsFlow.swift
//  Ororo-Player
//

import UIKit
import OroroKit
import Transitions

final class OpenSettingsFlow: Flow {

    struct Injection {
        let username: String
        let onLogout: () -> Void
    }

    // MARK: - Flow
    let coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
    ) {
        let viewController = SettingsViewController()
        viewController.title = "settings".localized()
        viewController.username = injection.username
        viewController.onSignOut = injection.onLogout

        let navigationController = UINavigationController(rootViewController: viewController)

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.inTabBar,
            params: (
                navigationController,
                UIImage(named: "series.tabbar.icon")
            )
        )
    }
}
