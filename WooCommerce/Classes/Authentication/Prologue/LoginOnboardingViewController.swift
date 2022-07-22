import UIKit

/// Contains a feature carousel with buttons that end up on the login prologue screen.
final class LoginOnboardingViewController: UIViewController {
    /// The action that leads to the dismissal.
    enum DismissAction {
        case next
        case skip
    }

    private let stackView: UIStackView = .init()
    private lazy var pageViewController = LoginProloguePageViewController(pageTypes: [.stats, .orderManagement, .products],
                                                                          showsSubtitle: true)
    private let analytics: Analytics
    private let onDismiss: (DismissAction) -> Void

    init(analytics: Analytics = ServiceLocator.analytics, onDismiss: @escaping (DismissAction) -> Void) {
        self.analytics = analytics
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureMainView()
        configureCurvedImageView()
        configureWooLogo()
        configureStackView()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.isPad() ? .all : .portrait
    }
}

private extension LoginOnboardingViewController {
    func configureMainView() {
        view.backgroundColor = .basicBackground

        let bottomView = UIView(frame: .zero)
        bottomView.backgroundColor = .authPrologueBottomBackgroundColor
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)
        NSLayoutConstraint.activate([
            bottomView.leadingAnchor.constraint(equalTo: view.safeLeadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.safeTrailingAnchor),
            bottomView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func configureCurvedImageView() {
        let imageView = UIImageView(image: .curvedRectangle.withRenderingMode(.alwaysTemplate))
        imageView.tintColor = .authPrologueBottomBackgroundColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.safeTopAnchor, constant: 52),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7)
        ])
    }

    func configureWooLogo() {
        let imageView = UIImageView(image: .wooLogoPrologueImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 176),
            imageView.heightAnchor.constraint(equalToConstant: 36),
            imageView.topAnchor.constraint(equalTo: view.safeTopAnchor, constant: 28)
        ])
    }

    func configureStackView() {
        configureStackViewSubviews()

        stackView.axis = .vertical
        stackView.spacing = Constants.stackViewSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        view.pinSubviewToSafeArea(stackView, insets: Constants.stackViewInsets)
    }

    func configureStackViewSubviews() {
        let carousel = createFeatureCarousel()

        let nextButton = createNextButton()
        let skipButton = createSkipButton()
        let buttonStackView: UIStackView = {
            let stackView = UIStackView(arrangedSubviews: [nextButton, skipButton])
            stackView.spacing = Constants.buttonStackViewSpacing
            stackView.axis = .vertical
            return stackView
        }()

        stackView.addArrangedSubviews([carousel, buttonStackView])
    }

    func createFeatureCarousel() -> UIView {
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(pageViewController)
        pageViewController.didMove(toParent: self)
        return pageViewController.view
    }

    func createNextButton() -> UIButton {
        let button = UIButton(frame: .zero)
        button.applyPrimaryButtonStyle()
        button.setTitle(Localization.continueButtonTitle, for: .normal)
        button.on(.touchUpInside) { [weak self] _ in
            guard let self = self else { return }
            guard self.pageViewController.goToNextPageIfPossible() else {
                return self.onDismiss(.next)
            }
            self.analytics.track(event: .LoginOnboarding.loginOnboardingNextButtonTapped(isFinalPage: false))
        }
        return button
    }

    func createSkipButton() -> UIButton {
        let button = UIButton(frame: .zero)
        button.accessibilityIdentifier = "Login Onboarding Skip Button"
        button.applyLinkButtonStyle()
        button.setTitle(Localization.skipButtonTitle, for: .normal)
        button.on(.touchUpInside) { [weak self] _ in
            self?.onDismiss(.skip)
        }
        return button
    }
}

private extension LoginOnboardingViewController {
    enum Localization {
        static let continueButtonTitle = NSLocalizedString("Next", comment: "The button title on the login onboarding screen to continue to the next step.")
        static let skipButtonTitle = NSLocalizedString("Skip", comment: "The button title on the login onboarding screen to skip to the prologue screen.")
    }

    enum Constants {
        static let stackViewInsets: UIEdgeInsets = .init(top: 52, left: 16, bottom: 20, right: 16)
        static let stackViewSpacing: CGFloat = 30
        static let buttonStackViewSpacing: CGFloat = 16
    }
}