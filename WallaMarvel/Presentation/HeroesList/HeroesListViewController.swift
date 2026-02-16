import UIKit
import Combine

final class HeroesListViewController: UIViewController {
    private let viewModel: HeroesListViewModel
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Hero>!
    private var cancellables = Set<AnyCancellable>()
    private let searchController = UISearchController(searchResultsController: nil)

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

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.text = "No heroes found"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()

    private enum Section { case main }

    init(viewModel: HeroesListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Heroes"
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupSearchController()
        setupStateViews()
        setupRefreshControl()
        configureDataSource()
        bindViewModel()
        viewModel.loadInitial()
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        collectionView.pinToSuperview()
    }

    private func setupSearchController() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search heroes..."
        searchController.searchBar.delegate = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupStateViews() {
        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    @objc private func didPullToRefresh() {
        viewModel.refresh()
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<HeroCell, Hero> { cell, _, hero in
            cell.configure(with: hero)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Hero>(collectionView: collectionView) {
            collectionView, indexPath, hero in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: hero)
        }
    }

    private func bindViewModel() {
        viewModel.$heroes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heroes in
                self?.applySnapshot(heroes: heroes)
            }
            .store(in: &cancellables)

        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
    }

    private func applySnapshot(heroes: [Hero]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Hero>()
        snapshot.appendSections([.main])
        snapshot.appendItems(heroes)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func updateUI(for state: HeroesListViewModel.State) {
        collectionView.refreshControl?.endRefreshing()

        switch state {
        case .idle:
            loadingIndicator.stopAnimating()
            errorLabel.isHidden = true
            emptyLabel.isHidden = true
        case .loading:
            loadingIndicator.startAnimating()
            errorLabel.isHidden = true
            emptyLabel.isHidden = true
            collectionView.isHidden = true
        case .loaded:
            loadingIndicator.stopAnimating()
            errorLabel.isHidden = true
            collectionView.isHidden = false
            emptyLabel.isHidden = !viewModel.heroes.isEmpty
        case .error(let message):
            loadingIndicator.stopAnimating()
            collectionView.isHidden = true
            errorLabel.isHidden = false
            errorLabel.text = message
            emptyLabel.isHidden = true
        }
    }
}

extension HeroesListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let hero = dataSource.itemIdentifier(for: indexPath) else { return }

        let detailVM = DependencyContainer.shared.makeHeroDetailViewModel(heroId: hero.id, heroName: hero.name)
        let detailVC = HeroDetailViewController(viewModel: detailVM)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let hero = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.loadNextPageIfNeeded(currentItem: hero)
    }
}

extension HeroesListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.searchQuery = searchText
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.searchQuery = ""
    }
}
