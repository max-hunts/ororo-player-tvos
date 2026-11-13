//
//  ShowEpisodeOptionsFlow.swift
//  Ororo-Player-iOS
//
//  Created by Max Ovtsin on 28/4/19.
//  Copyright © 2019 Max Ovtsin. All rights reserved.
//

import UIKit
import OroroKit
import Transitions

final class ShowEpisodeOptionsFlow: Flow {

    struct Injection {
        let episode: Episode
        let serviceProvider: ServiceProvider
        let completion: (() -> Void)?
    }

    // MARK: - Flow interface
    let coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
        ) {

        let alertController = getController(
            injection: injection,
            coordinator: coordinator
        )

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.modal,
            params: alertController
        )
    }

    // MARK: - Private functions

    private func getController(
        injection: Injection,
        coordinator: Coordinator
        ) -> UIAlertController {
        let alertController = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        let removeAction = UIAlertAction(title: "remove_from_favorites".localized(),
                                           style: .default) { (_) in

                                            //                                            self.removeFromFavourites(episode: episode,
                                            //                                                                      comletion: completion)
        }

        let cancelAction = UIAlertAction(title: "cancel".localized(),
                                         style: .cancel) { (_) in }

        alertController.addAction(removeAction)
        alertController.addAction(cancelAction)

        return alertController
    }

    private func removeFromFavourites(
        episode: Episode,
        serviceProvider: ServiceProvider,
        comletion: (() -> Void)?
        ) {
        serviceProvider.storageService
            .performAsync(transaction: { (context) in
                let episode = context.fetchOne(
                    "id == %@",
                    arguments: [episode.id]
                    ) as CDEpisode?
                episode?.playbackProgress = 0.0
            }, completion: comletion)
    }
}
