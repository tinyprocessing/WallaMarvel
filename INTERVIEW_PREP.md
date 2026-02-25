# WallaMarvel - Technical Interview Preparation Guide

## 1. Architecture Overview

### What You Built
A Marvel/Comic characters browser app using **MVVM + Clean Architecture** with three layers:

```
┌─────────────────────────────────────────────────────┐
│  PRESENTATION (MVVM)                                │
│  ViewController ←──Combine──→ ViewModel             │
├─────────────────────────────────────────────────────┤
│  DOMAIN (Pure Swift)                                │
│  UseCases ←── Repository Protocol ←── Hero Model    │
├─────────────────────────────────────────────────────┤
│  DATA                                               │
│  APIClient → DTOs → DataSources → Repository Impl   │
└─────────────────────────────────────────────────────┘
```

**Key decisions:**
- UIKit (not SwiftUI) — full control, demonstrates proficiency
- Combine for ViewModel→View bindings (`@Published`)
- async/await for all networking (no completion handlers)
- Zero third-party dependencies (UIKit, Combine, Foundation only)

---

## 2. Questions They Might Ask About Your Code

### "Why did you choose MVVM + Clean Architecture?"

**Your answer:** Clean Architecture separates concerns into layers with strict dependency rules — the Domain layer has zero framework imports, making it purely testable. MVVM on top gives reactive UI updates via Combine's `@Published`. The key benefit: I can swap the entire data source (API vs Mock) without touching any ViewModel or View code, as proven by the `DefaultHeroRepository` fallback pattern.

**Be ready for:** "Isn't Clean Architecture overkill for this app size?"
**Counter:** For this scope, yes — the UseCases are thin pass-throughs. But it demonstrates understanding of the pattern. In a real production app with business rules (e.g., filtering heroes by subscription tier, caching policies), the UseCase layer earns its keep. The trade-off is more boilerplate for better testability and maintainability.

---

### "Walk us through how data flows from API to UI"

```
1. User scrolls to bottom → willDisplay triggers loadNextPageIfNeeded()
2. ViewModel calls GetHeroesUseCase.execute(offset:limit:)
3. UseCase calls HeroRepositoryProtocol.getHeroes()
4. DefaultHeroRepository tries ComicVineDataSource first
5. DataSource builds Endpoint → URLSessionAPIClient.request()
6. URLSession fetches data, decodes ComicVineResponse<[ComicVineCharacterDTO]>
7. DTOs mapped to [Hero] via toDomain() extension
8. ViewModel receives heroes, deduplicates via Set<Int>, appends
9. @Published heroes triggers Combine pipeline
10. ViewController receives on main thread, applies DiffableDataSource snapshot
11. UICollectionView animates the diff
```

If step 4 fails → `DefaultHeroRepository` catches error → calls `MockDataSource` → app works with bundled JSON.

---

### "Why no third-party dependencies?"

**Your answer:** For an app this size, native solutions cover everything:
- **Image loading**: `ImageLoader` actor with NSCache replaces Kingfisher/SDWebImage
- **Networking**: URLSession + async/await replaces Alamofire
- **Reactive**: Combine replaces RxSwift

**Trade-offs to acknowledge:**
- Kingfisher handles disk caching, progressive loading, image processors — my ImageLoader only does memory cache
- Alamofire offers request interceptors, retry policies, certificate pinning
- In a production app with 50+ engineers, established libraries reduce onboarding friction

---

### "Explain your ImageLoader design"

```swift
actor ImageLoader {
    private let cache = NSCache<NSURL, UIImage>()       // Memory cache
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]  // Dedup
}
```

Three key features:
1. **Actor isolation** — thread-safe without locks or dispatch queues
2. **In-flight deduplication** — if 3 cells request the same image, only 1 network call
3. **Cancellation** — `prepareForReuse()` cancels pending loads, preventing stale images

**What's missing (improvement opportunity):**
- No disk cache — images re-downloaded after app restart
- No image downsampling — full-size images decoded into memory
- No retry logic on transient failures

---

### "How do you handle pagination?"

Offset-based pagination with deduplication:
- Page size: 20, tracked via `currentOffset` and `totalResults`
- Triggered when `willDisplay` fires for the last cell
- **Deduplication via `Set<Int>`**: Comic Vine API can return duplicate IDs across pages; `seenIds` filters them
- `hasMorePages` computed from `currentOffset < totalResults`
- On search query change → pagination resets entirely

---

### "How does your search work?"

```swift
$searchQuery
    .dropFirst()           // Skip initial empty value
    .removeDuplicates()    // Don't re-search same query
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] query in ... }
```

- **300ms debounce** prevents API spam while typing
- Previous search `Task` is cancelled on new query
- Empty query → switches back to browse mode
- Mock fallback: client-side case-insensitive filtering

---

### "Tell us about your testing strategy"

31 unit tests across 6 test suites:

| Suite | Tests | What it covers |
|-------|-------|----------------|
| HeroesListViewModelTests | 6 | Load, pagination, refresh, error states |
| HeroDetailViewModelTests | 3 | Load success/error, initial state |
| DefaultHeroRepositoryTests | 2 | Primary/fallback behavior |
| DTOMappingTests | 9 | Field mapping, nil handling, fallback logic |
| DTODecodingTests | 4 | JSON parsing, response wrappers |
| HeroDetailVCTests | 7 | UI state transitions, HTML stripping |

**Pattern:** Mock repository injected via protocol → no network in tests → deterministic results.

**What's missing (improvement opportunity):**
- No snapshot/UI tests
- No integration tests (real API)
- Async tests use `Task.sleep` instead of `XCTestExpectation` — fragile
- No test for search debounce behavior
- No test for image loading/caching

---

## 3. Possible Improvements They Might Ask About

### 3.1 Architecture Improvements

**Coordinator Pattern for Navigation**
Currently: `HeroesListViewController` creates the detail screen directly via `DependencyContainer`.
Problem: View controllers know about navigation flow.
Improvement: A `Coordinator` protocol manages navigation, making flows testable and reusable.

```swift
protocol Coordinator {
    func start()
}

class HeroesCoordinator: Coordinator {
    func showDetail(heroId: Int, heroName: String) {
        let vm = container.makeHeroDetailViewModel(heroId: heroId, heroName: heroName)
        let vc = HeroDetailViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }
}
```

**Replace Singleton DependencyContainer with proper DI**
Currently: `DependencyContainer.shared` is a singleton accessed from SceneDelegate and ViewControllers.
Problem: Singletons create hidden dependencies, make testing harder.
Improvement: Use constructor injection throughout, or a DI framework like Swinject. Pass the container down from SceneDelegate.

**Replace `DependencyContainer.shared` calls in ViewControllers**
Currently: `HeroesListViewController` calls `DependencyContainer.shared.makeHeroDetailViewModel(...)` in `didSelectItemAt`.
This is a **Dependency Rule violation** — Presentation layer directly depends on the DI container.
Fix: Inject a factory closure `(Int, String) -> HeroDetailViewModel` into the ViewController.

---

### 3.2 Networking Improvements

**Add Disk Caching**
The `ImageLoader` only uses `NSCache` (memory). Adding `URLCache` or a custom disk cache would:
- Reduce data usage on re-launch
- Improve perceived performance
- Allow offline image viewing

**Request Retry with Exponential Backoff**
Currently: single attempt, then fallback to mock.
Better: retry transient failures (timeouts, 5xx) 2-3 times before falling back.

**Cancel In-Flight Requests on Screen Exit**
Currently: if user leaves list while loading, the request completes and wastes resources.
Better: store the `Task` reference and cancel it in `deinit` or `viewDidDisappear`.

**API Key Security**
Currently: API key is in xcconfig files (committed to repo).
Better: Use environment variables, `.env` files in `.gitignore`, or a secure secrets manager. For production: server-side proxy to hide API keys entirely.

---

### 3.3 UI/UX Improvements

**Skeleton Loading / Shimmer Effect**
Currently: full-screen spinner while loading.
Better: skeleton placeholders (gray rectangles) that shimmer — gives perception of speed.

**Image Downsampling**
Currently: full-resolution images loaded into memory.
Problem: A 2000x3000px image wastes memory for a 64x64 cell thumbnail.
Fix: Use `CGImageSourceCreateThumbnailAtIndex` or `UIGraphicsImageRenderer` to downsample before caching.

**Error Recovery UI**
Currently: error label shown, user must pull-to-refresh.
Better: "Retry" button, or auto-retry with exponential backoff.

**Empty State Design**
Currently: "No heroes found" text label.
Better: Illustrated empty state with actionable guidance.

**SwiftUI Migration Path**
The MVVM + `@Published` pattern maps directly to SwiftUI:
- `@Published` → `@Published` (same)
- `ViewController` → `View`
- `DiffableDataSource` → `ForEach` + `LazyVStack`
- Combine bindings → `@StateObject` / `@ObservedObject`

---

### 3.4 Testing Improvements

**Replace `Task.sleep` with `XCTestExpectation`**
```swift
// Current (fragile):
try await Task.sleep(nanoseconds: 200_000_000)
XCTAssertEqual(viewModel.state, .loaded)

// Better:
let expectation = expectation(description: "Heroes loaded")
viewModel.$state.dropFirst().sink { state in
    if state == .loaded { expectation.fulfill() }
}.store(in: &cancellables)
viewModel.loadInitial()
await fulfillment(of: [expectation], timeout: 1.0)
```

**Add Snapshot Tests**
Use a library like `swift-snapshot-testing` to capture cell/screen renders and detect visual regressions.

**Test the Search Debounce**
Verify that rapid query changes only trigger one API call after the 300ms window.

**Integration Tests with Mock Server**
Use `URLProtocol` subclass to intercept network requests in tests — test the full stack without hitting the real API.

---

### 3.5 Performance Improvements

**Prefetching**
`UICollectionViewDataSourcePrefetching` can start image downloads for cells about to appear, reducing visible loading.

**Image Cache Eviction Strategy**
NSCache evicts automatically under memory pressure, but adding a configurable TTL (time-to-live) prevents serving stale images.

**Diffable Data Source Optimization**
Currently applies full snapshots. For large datasets, use `reconfigureItems` (iOS 15+) instead of `reloadItems` to avoid cell recreation.

---

## 4. Alternative Approaches They Might Ask About

### "Why UIKit instead of SwiftUI?"

| Aspect | UIKit (your choice) | SwiftUI |
|--------|---------------------|---------|
| Maturity | Battle-tested, full API | Still evolving, some UIKit gaps |
| Control | Pixel-perfect | Declarative, less control |
| Industry | Most production apps | Growing adoption |
| Testing | XCTest + UI Tests | Preview + snapshot |
| Navigation | UINavigationController | NavigationStack (iOS 16+) |

**Your position:** UIKit was the pragmatic choice for demonstrating iOS proficiency. The MVVM pattern I used maps cleanly to SwiftUI if migration is needed.

---

### "Why Combine instead of closures/delegates?"

| Approach | Pros | Cons |
|----------|------|------|
| **Combine** (your choice) | Declarative, debounce/throttle built-in, chain operators | Learning curve, iOS 13+ only |
| **Closures** | Simple, no framework dependency | Callback nesting, manual debounce |
| **Delegates** | UIKit-native pattern | Verbose, 1:1 relationship |
| **RxSwift** | Mature, huge operator library | Third-party dependency, heavy |
| **AsyncSequence** | Pure Swift, no framework | Less operator support than Combine |

---

### "Why async/await instead of Combine for networking?"

async/await is more readable for request-response patterns:
```swift
// async/await (your code)
let heroes = try await repository.getHeroes(offset: 0, limit: 20)

// Combine alternative
repository.getHeroes(offset: 0, limit: 20)
    .receive(on: DispatchQueue.main)
    .sink(receiveCompletion: { ... }, receiveValue: { ... })
    .store(in: &cancellables)
```

async/await wins for one-shot operations. Combine wins for continuous streams (like search debounce — which is why you used both).

---

### "What if you had to use a different API?"

The Clean Architecture makes this trivial:
1. Create a new `DataSource` implementing `HeroRepositoryProtocol`
2. Write new DTOs + mapping extensions
3. Swap the data source in `DependencyContainer`
4. **Zero changes** to Domain layer, ViewModels, or Views

This is exactly what `MockDataSource` demonstrates — a completely different data source that conforms to the same protocol.

---

## 5. iOS Concepts You Should Be Ready to Discuss

### Patterns
- **MVVM** — how ViewModel exposes state, why not MVC
- **Repository Pattern** — abstracting data source from business logic
- **Dependency Injection** — constructor injection vs service locator
- **Coordinator** — navigation decoupled from VCs (you didn't use it, know why/when)
- **Strategy Pattern** — your Primary/Fallback repository

### Concurrency
- **async/await** — structured concurrency, Task lifecycle
- **Actors** — your ImageLoader, data race prevention
- **@MainActor** — why ViewModel state updates need main thread
- **Task cancellation** — cooperative cancellation, `Task.isCancelled`

### UIKit
- **DiffableDataSource** — why it's better than reloadData (no index-out-of-bounds crashes)
- **CompositionalLayout** — declarative, flexible layouts
- **Cell reuse** — prepareForReuse, image loading race conditions
- **UISearchController** — integration with navigation bar

### Testing
- **Protocol-based mocking** — how protocols enable test doubles
- **Test doubles**: Mock (verifies interactions) vs Stub (returns canned data) vs Fake (working impl)
- **Your mock repository** tracks call counts (Mock) AND returns data (Stub) — it's actually both

### Memory Management
- **[weak self]** in closures/Combine sinks
- **NSCache** — automatic eviction under memory pressure
- **Task lifecycle** — tasks hold strong references until completion
- **prepareForReuse** — cancel image loads to prevent memory waste

---

## 6. Strengths of Your Submission

1. **Zero dependencies** — shows you understand the frameworks, not just libraries
2. **Clean separation** — Domain layer is pure Swift, fully testable
3. **Modern Swift** — async/await, actors, Combine, DiffableDataSource
4. **Fallback strategy** — app works even when API is down
5. **31 unit tests** — covers ViewModels, Repository, DTO mapping, ViewController
6. **Deduplication** — handles API returning duplicate heroes across pages
7. **Actor-based ImageLoader** — thread-safe without locks
8. **Accessibility** — screen reader labels, grouped elements
9. **API key management** — xcconfig files separate secrets from code
10. **Debounced search** — prevents API spam, good UX

---

## 7. Weaknesses to Acknowledge Proactively

Being honest about trade-offs shows maturity:

1. **UseCases are thin** — just pass-through to repository. Justified by Clean Architecture pattern, but could be collapsed for this app size.
2. **No Coordinator** — navigation lives in ViewController. Fine for 2 screens, problematic at scale.
3. **DependencyContainer is a singleton** — ideally would use constructor injection throughout.
4. **Tests use `Task.sleep`** — should use `XCTestExpectation` for deterministic async testing.
5. **No disk cache for images** — only NSCache (memory).
6. **HTML in descriptions** — stripped with regex, which is fragile. Should use `NSAttributedString` with HTML parsing.
7. **API key in xcconfig committed to repo** — should be in `.gitignore` or environment variables.
8. **No error differentiation in UI** — user sees same generic error for network/server/parsing failures.

---

## 8. Quick Reference: File Map

```
WallaMarvel/
├── App/
│   ├── AppDelegate.swift          ← Minimal, standard setup
│   ├── SceneDelegate.swift        ← Window setup, root VC
│   └── DependencyContainer.swift  ← Factory pattern, lazy init
├── Domain/
│   ├── Models/Hero.swift          ← Identifiable, Hashable
│   ├── Repositories/HeroRepository.swift  ← Protocol (3 methods)
│   └── UseCases/                  ← GetHeroes, GetDetail, Search
├── Data/
│   ├── Network/                   ← APIClient, Endpoint, APIError
│   ├── DataSources/
│   │   ├── ComicVine/             ← Real API integration
│   │   └── Mock/                  ← Bundled JSON fallback
│   └── Repositories/              ← DefaultHeroRepository (primary+fallback)
├── Presentation/
│   ├── HeroesList/                ← VC + VM + Cell
│   ├── HeroDetail/                ← VC + VM
│   └── Common/                    ← ImageLoader (actor), UIView extension
└── Tests/                         ← 31 unit tests, 6 suites
```

