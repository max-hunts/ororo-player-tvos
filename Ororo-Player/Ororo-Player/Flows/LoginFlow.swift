//
//  LoginFlow.swift
//  Ororo-Player
//

import UIKit
import OroroKit
import Transitions

final class LoginFlow: Flow {

    struct Injection {
        let credentialsStore: CredentialsStore
        let onSuccess: (Credentials) -> Void
    }

    // MARK: - Flow
    let coordinator: Coordinator

    // Retained for the duration of the async validation network call
    private var validationProvider: ServiceProvider?

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func start(
        injection: Injection,
        transitionHandler: TransitionHandler
    ) {
        let viewController = LoginViewController()

        viewController.onLogin = { [weak self] username, password in
            guard let self = self else { return }
            viewController.setLoading(true)

            let credentials = Credentials(username: username, password: password)
            let provider = ServiceProvider(credentials: credentials)
            self.validationProvider = provider

            // Validate by making a real network request — bypasses the data provider
            // cache so stale CoreData from a previous account doesn't mask bad credentials.
            provider.network.request(
                with: ApiServiceEnpoint.movies,
                onSuccess: { [weak self] (_: Movies) in
                    self?.validationProvider = nil
                    viewController.setLoading(false)
                    injection.credentialsStore.save(credentials)
                    injection.onSuccess(credentials)
                },
                onError: { [weak self] error in
                    self?.validationProvider = nil
                    viewController.setLoading(false)
                    let nsError = error as NSError
                    if nsError.code == -1009 {
                        viewController.showError("no_internet".localized())
                    } else {
                        viewController.showError("invalid_credentials".localized())
                    }
                }
            )
        }

        transitionHandler.present(
            flow: self,
            transition: BaseTransition.root,
            params: viewController
        )
    }
}
