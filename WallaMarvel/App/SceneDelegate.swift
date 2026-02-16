import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        let viewModel = DependencyContainer.shared.makeHeroesListViewModel()
        let heroesListVC = HeroesListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: heroesListVC)
        navigationController.navigationBar.prefersLargeTitles = true

        window.rootViewController = navigationController
        self.window = window
        self.window?.makeKeyAndVisible()
    }
}
