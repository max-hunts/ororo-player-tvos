//
//  LoginViewController.swift
//  Ororo-Player
//

import UIKit
import OroroKit

class LoginViewController: UIViewController {

    // MARK: - Properties
    var onLogin: ((String, String) -> Void)?

    private let titleLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: DeviceVisualTheme.loaderSpinnerStyle())

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Public interface
    func setLoading(_ loading: Bool) {
        signInButton.isEnabled = !loading
        if loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    // MARK: - Actions
    @objc private func signInTapped() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showError("sign_in_empty_fields".localized())
            return
        }
        errorLabel.isHidden = true
        onLogin?(email, password)
    }

    // MARK: - Private functions
    private func setupUI() {
        view.backgroundColor = DeviceVisualTheme.backgroundColor

        titleLabel.text = "Ororo"
        titleLabel.font = DeviceVisualTheme.titleFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        emailField.placeholder = "email".localized()
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.borderStyle = .roundedRect
        emailField.font = UIFont.systemFont(ofSize: DeviceVisualTheme.descriptionFontSize)

        passwordField.placeholder = "password".localized()
        passwordField.isSecureTextEntry = true
        passwordField.borderStyle = .roundedRect
        passwordField.font = UIFont.systemFont(ofSize: DeviceVisualTheme.descriptionFontSize)

        signInButton.setTitle("sign_in".localized(), for: .normal)
        signInButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: DeviceVisualTheme.descriptionFontSize)
        signInButton.addTarget(self, action: #selector(signInTapped), for: .primaryActionTriggered)

        errorLabel.textColor = .red
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont.systemFont(ofSize: DeviceVisualTheme.descriptionFontSize)
        errorLabel.isHidden = true
        errorLabel.numberOfLines = 0

        spinner.hidesWhenStopped = true

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            emailField,
            passwordField,
            signInButton,
            errorLabel,
            spinner
        ])
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill

        view.addSubview(stackView)
        stackView.layout {
            $0.centerX <-> view.centerX
            $0.centerY <-> view.centerY
            $0.width <-> 600
        }

        emailField.layout { $0.height <-> 80 }
        passwordField.layout { $0.height <-> 80 }
        signInButton.layout { $0.height <-> 80 }
    }
}
