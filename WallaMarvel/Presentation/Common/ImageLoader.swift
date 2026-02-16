import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func loadImage(from url: URL?) async -> UIImage? {
        guard let url = url else { return nil }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existingTask = inFlightTasks[url] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: url as NSURL, cost: data.count)
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[url] = task
        let image = await task.value
        inFlightTasks.removeValue(forKey: url)
        return image
    }

    func cancelLoad(for url: URL?) {
        guard let url = url else { return }
        inFlightTasks[url]?.cancel()
        inFlightTasks.removeValue(forKey: url)
    }
}
