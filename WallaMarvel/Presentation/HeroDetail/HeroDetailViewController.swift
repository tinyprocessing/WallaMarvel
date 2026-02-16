import UIKit
import Combine

final class HeroDetailViewController: UIViewController {
    private let viewModel: HeroDetailViewModel
    private var cancellables = Set<AnyCancellable>()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let heroImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.isAccessibilityElement = true
        iv.accessibilityTraits = .image
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.numberOfLines = 0
        return label
    }()

    private let realNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let publisherLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .tertiaryLabel
        return label
    }()

    private let deckLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()

    init(viewModel: HeroDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.heroName
        view.backgroundColor = .systemBackground
        setupUI()
        bindViewModel()
        viewModel.loadDetail()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            heroImageView.heightAnchor.constraint(equalToConstant: 300),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        contentStack.addArrangedSubview(heroImageView)

        let textContainer = UIStackView()
        textContainer.axis = .vertical
        textContainer.spacing = 8
        textContainer.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
        textContainer.isLayoutMarginsRelativeArrangement = true

        textContainer.addArrangedSubview(nameLabel)
        textContainer.addArrangedSubview(realNameLabel)
        textContainer.addArrangedSubview(publisherLabel)
        textContainer.addArrangedSubview(makeSpacer(height: 4))
        textContainer.addArrangedSubview(deckLabel)
        textContainer.addArrangedSubview(makeSpacer(height: 8))
        textContainer.addArrangedSubview(descriptionLabel)

        contentStack.addArrangedSubview(textContainer)

        scrollView.isHidden = true
    }

    private func makeSpacer(height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateUI(for state: HeroDetailViewModel.State) {
        switch state {
        case .loading:
            loadingIndicator.startAnimating()
            scrollView.isHidden = true
            errorLabel.isHidden = true
        case .loaded(let hero):
            loadingIndicator.stopAnimating()
            scrollView.isHidden = false
            errorLabel.isHidden = true
            configureContent(with: hero)
        case .error(let message):
            loadingIndicator.stopAnimating()
            scrollView.isHidden = true
            errorLabel.isHidden = false
            errorLabel.text = message
        }
    }

    private func configureContent(with hero: Hero) {
        nameLabel.text = hero.name
        realNameLabel.text = hero.realName
        realNameLabel.isHidden = hero.realName == nil
        publisherLabel.text = hero.publisher
        publisherLabel.isHidden = hero.publisher == nil
        deckLabel.text = hero.deck
        deckLabel.isHidden = hero.deck == nil

        if let htmlDesc = hero.description {
            let cleaned = htmlDesc.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            descriptionLabel.text = cleaned
            descriptionLabel.isHidden = cleaned.isEmpty
        } else {
            descriptionLabel.isHidden = true
        }

        addSectionIfNeeded(title: "Powers", items: hero.powers)
        addSectionIfNeeded(title: "Teams", items: hero.teams)

        if let firstAppearance = hero.firstAppearance {
            addInfoRow(title: "First Appearance", value: firstAppearance)
        }

        if !hero.aliases.isEmpty {
            addInfoRow(title: "Aliases", value: hero.aliases.joined(separator: ", "))
        }

        heroImageView.accessibilityLabel = "\(hero.name) portrait"

        if let url = hero.imageURL {
            Task { [weak self] in
                let image = await ImageLoader.shared.loadImage(from: url)
                self?.heroImageView.image = image
            }
        }
    }

    private func addSectionIfNeeded(title: String, items: [String]) {
        guard !items.isEmpty else { return }

        let sectionLabel = UILabel()
        sectionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionLabel.text = title

        let flowContainer = UIView()
        flowContainer.translatesAutoresizingMaskIntoConstraints = false

        let tags = items.map { makeTag(text: $0) }
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let spacing: CGFloat = 8

        for tag in tags {
            tag.translatesAutoresizingMaskIntoConstraints = false
            flowContainer.addSubview(tag)

            let tagSize = tag.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if currentX + tagSize.width > UIScreen.main.bounds.width - 64 && currentX > 0 {
                currentX = 0
                currentY += tagSize.height + spacing
            }

            tag.leadingAnchor.constraint(equalTo: flowContainer.leadingAnchor, constant: currentX).isActive = true
            tag.topAnchor.constraint(equalTo: flowContainer.topAnchor, constant: currentY).isActive = true
            currentX += tagSize.width + spacing
        }

        if let lastTag = tags.last {
            let lastSize = lastTag.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            flowContainer.heightAnchor.constraint(equalToConstant: currentY + lastSize.height).isActive = true
        }

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, flowContainer])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        sectionStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        sectionStack.isLayoutMarginsRelativeArrangement = true

        sectionStack.isAccessibilityElement = true
        sectionStack.accessibilityLabel = "\(title): \(items.joined(separator: ", "))"

        contentStack.addArrangedSubview(sectionStack)
    }

    private func makeTag(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemBlue

        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        container.layer.cornerRadius = 12
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
        ])

        return container
    }

    private func addInfoRow(title: String, value: String) {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.text = title

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 0
        valueLabel.text = value

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(title): \(value)"

        contentStack.addArrangedSubview(stack)
    }
}
