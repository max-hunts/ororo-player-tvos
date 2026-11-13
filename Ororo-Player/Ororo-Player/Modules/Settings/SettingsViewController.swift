//
//  SettingsViewController.swift
//  Ororo-Player
//

import UIKit
import OroroKit

class SettingsViewController: UIViewController {

    // MARK: - Properties
    var username: String = ""
    var onSignOut: (() -> Void)?

    private let signedInLabel = UILabel()
    private let signOutButton = UIButton(type: .system)

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Actions
    @objc private func signOutTapped() {
        let alert = UIAlertController(
            title: "sign_out".localized(),
            message: "sign_out_confirmation".localized(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "cancel".localized(), style: .cancel))
        alert.addAction(UIAlertAction(title: "sign_out".localized(), style: .destructive) { [weak self] _ in
            self?.onSignOut?()
        })
        present(alert, animated: true)
    }

    // MARK: - Private functions
    private func setupUI() {
        view.backgroundColor = DeviceVisualTheme.backgroundColor
        title = "settings".localized()

        signedInLabel.text = "\("signed_in_as".localized()) \(username)"
        signedInLabel.font = UIFont.systemFont(ofSize: DeviceVisualTheme.descriptionFontSize)
        signedInLabel.textColor = .white
        signedInLabel.textAlignment = .center
        signedInLabel.numberOfLines = 0

        signOutButton.setTitle("sign_out".localized(), for: .normal)
        signOutButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: DeviceVisualTheme.descriptionFontSize)
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .primaryActionTriggered)

        let stackView = UIStackView(arrangedSubviews: [signedInLabel, signOutButton])
        stackView.axis = .vertical
        stackView.spacing = 40
        stackView.alignment = .center

        view.addSubview(stackView)
        stackView.layout {
            $0.centerX <-> view.centerX
            $0.centerY <-> view.centerY
        }

        signOutButton.layout {
            $0.height <-> 80
            $0.width <-> 400
        }
    }
}
