import UIKit

final class HeroCell: UICollectionViewCell {
    static let reuseIdentifier = "HeroCell"

    private let heroImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.numberOfLines = 1
        return label
    }()

    private let deckLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var currentImageURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let textStack = UIStackView(arrangedSubviews: [nameLabel, deckLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(heroImageView)
        contentView.addSubview(textStack)
        contentView.addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            heroImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            heroImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 64),
            heroImageView.heightAnchor.constraint(equalToConstant: 64),
            heroImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            heroImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            textStack.leadingAnchor.constraint(equalTo: heroImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
        ])

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        contentView.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
        ])

        isAccessibilityElement = true
    }

    func configure(with hero: Hero) {
        nameLabel.text = hero.name
        deckLabel.text = hero.deck
        accessibilityLabel = hero.name
        accessibilityHint = hero.deck

        heroImageView.image = nil
        currentImageURL = hero.thumbURL

        if let url = hero.thumbURL {
            Task { [weak self] in
                let image = await ImageLoader.shared.loadImage(from: url)
                guard self?.currentImageURL == url else { return }
                self?.heroImageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        heroImageView.image = nil
        nameLabel.text = nil
        deckLabel.text = nil
        Task { [url = currentImageURL] in
            await ImageLoader.shared.cancelLoad(for: url)
        }
        currentImageURL = nil
    }
}
