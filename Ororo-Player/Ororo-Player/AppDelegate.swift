//
//  AppDelegate.swift
//  Ororo-Player
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import Transitions
import OroroKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties
    private let coordinator = MainCoordinator()
    private let credentialsStore = CredentialsStore()

    // MARK: - UIApplicationDelegate
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if let credentials = credentialsStore.load() {
            launchMain(with: credentials)
        } else {
            launchLogin()
        }

        return true
    }

    // MARK: - Private functions
    private func launchMain(with credentials: Credentials) {
        coordinator.launch(
            rootFlowType: RootFlow.self,
            injection: RootFlow.Injection(
                serviceProvider: ServiceProvider(credentials: credentials),
                credentialsStore: credentialsStore
            )
        )
    }

    private func launchLogin() {
        coordinator.launch(
            rootFlowType: LoginFlow.self,
            injection: LoginFlow.Injection(
                credentialsStore: credentialsStore,
                onSuccess: { [weak self] credentials in
                    guard let self = self else { return }
                    self.coordinator.show(
                        RootFlow.self,
                        injection: RootFlow.Injection(
                            serviceProvider: ServiceProvider(credentials: credentials),
                            credentialsStore: self.credentialsStore
                        )
                    )
                }
            )
        )
    }
}
