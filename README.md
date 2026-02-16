# WallaMarvel

A superhero browser app built with UIKit, demonstrating Clean Architecture, MVVM, and modern Swift concurrency.

## Architecture

The project follows **MVVM + Clean Architecture** with three distinct layers:

```
Presentation (MVVM)          Domain                    Data
ViewController ──> ViewModel ──> UseCase ──> Repository ──> DataSource
     │                │              │           │              │
  UIKit views    @Published      Protocol    Protocol     Comic Vine API
  Combine        state mgmt     boundary    boundary      Mock JSON
```

### Why MVVM over MVP

The original project used MVP. I migrated to MVVM because:

- **Combine bindings** eliminate boilerplate delegate/callback code between View and ViewModel
- **@Published properties** provide a reactive, declarative way to drive UI state
- **Testability** — ViewModels have no reference to UIKit, making them straightforward to unit test with simple property assertions
- **State management** — A single `State` enum per ViewModel makes transitions explicit and exhaustive

### Layer Responsibilities

- **Domain** — Pure Swift models (`Hero`), repository protocols, and use cases. No framework imports. This layer defines what the app does without knowing how.
- **Data** — Network client, DTOs, data source implementations, and repository. Handles API communication, JSON mapping, and the primary/fallback data source strategy.
- **Presentation** — ViewControllers, ViewModels, cells, and image loading. All UIKit code lives here.

## Key Decisions

### Comic Vine API instead of Marvel API

The Marvel API has been unreliable. I replaced it with the [Comic Vine API](https://comicvine.gamespot.com/api/), which provides similar superhero data (characters, powers, teams, publishers) and supports pagination and search. The app uses Comic Vine as the primary data source with a local mock JSON fallback for resilience.

### Primary/Fallback Data Source Pattern

`DefaultHeroRepository` tries the Comic Vine API first. If it fails (network error, rate limit, etc.), it transparently falls back to `MockDataSource`, which serves bundled JSON data with client-side pagination and search. This means the app always works — even offline.

### No Third-Party Dependencies

I removed Kingfisher and implemented a custom `ImageLoader` using:

- `URLSession` for async image fetching
- `NSCache` for in-memory caching (automatically evicted under memory pressure)
- In-flight request deduplication via an actor-based task map
- Cancellation support on cell reuse

For an app of this scope, a native solution avoids dependency management overhead and demonstrates understanding of the underlying APIs.

### UICollectionView with DiffableDataSource

Replaced `UITableView` with `UICollectionView` + `UICollectionViewCompositionalLayout` + `UICollectionViewDiffableDataSource`:

- **DiffableDataSource** handles animated updates and eliminates index-out-of-bounds crashes
- **CompositionalLayout** provides a modern, declarative layout system
- **Deduplication** — The Comic Vine API can return duplicate character IDs across pages. A `Set<Int>` filter ensures DiffableDataSource never receives duplicate identifiers.

### Async/Await Throughout

All networking uses `async/await` instead of completion handlers:

- Cleaner error propagation with `try/catch`
- No callback pyramids or retain cycle concerns
- `Task` cancellation for in-flight requests on pagination reset or cell reuse
- Debounced search uses Combine's `.debounce()` operator feeding into async tasks

### API Key Security

The API key is stored in `.xcconfig` files (one per build configuration) that are git-ignored. The key flows through `Info.plist` as `$(COMIC_VINE_API_KEY)` and is read at runtime via `Bundle.main.infoDictionary`. This keeps secrets out of source control while remaining simple to configure.

To configure the project, create `Configuration/Debug.xcconfig` and `Configuration/Release.xcconfig` with:
```
COMIC_VINE_API_KEY = your_api_key_here
```

### Accessibility

- **HeroCell**: `isAccessibilityElement = true`, `accessibilityLabel` (hero name), `accessibilityHint` (description)
- **HeroDetailViewController**: Image has `accessibilityLabel` and `.image` trait. Powers, teams, aliases, and first appearance sections are grouped as single accessibility elements with descriptive labels. VoiceOver reads them as "Powers: Flight, Super Strength" rather than individual tags.

## What Was Fixed from the Original Code

1. **Hardcoded API keys in source** — Moved to `.xcconfig` files, git-ignored
2. **`NSAllowsArbitraryLoads = YES`** — Removed. Comic Vine uses HTTPS; no ATS exception needed
3. **No error handling** — Added typed errors (`APIError`), fallback data source, and user-facing error states
4. **No pagination** — Implemented offset-based pagination with page size of 20, tracking total results
5. **MVP architecture** — Migrated to MVVM with Combine bindings
6. **UITableView** — Replaced with UICollectionView + DiffableDataSource + CompositionalLayout
7. **Kingfisher dependency** — Replaced with native async image loading + NSCache
8. **No detail screen** — Added full hero detail with image, bio, powers, teams, aliases, first appearance
9. **No search** — Added debounced search bar using UISearchController
10. **No tests** — Added 31 unit tests covering ViewModels, repository, DTO mapping/decoding, and ViewController behavior

## Project Structure

```
WallaMarvel/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── DependencyContainer.swift
├── Domain/
│   ├── Models/Hero.swift
│   ├── Repositories/HeroRepository.swift
│   └── UseCases/
│       ├── GetHeroesUseCase.swift
│       ├── GetHeroDetailUseCase.swift
│       └── SearchHeroesUseCase.swift
├── Data/
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── APIError.swift
│   │   └── Endpoint.swift
│   ├── DataSources/
│   │   ├── ComicVine/
│   │   │   ├── ComicVineDataSource.swift
│   │   │   ├── ComicVineEndpoints.swift
│   │   │   └── DTOs/
│   │   │       ├── ComicVineResponse.swift
│   │   │       ├── ComicVineCharacterDTO.swift
│   │   │       └── ComicVineCharacterDTO+Mapping.swift
│   │   └── Mock/
│   │       ├── MockDataSource.swift
│   │       └── MockData.json
│   └── Repositories/DefaultHeroRepository.swift
├── Presentation/
│   ├── HeroesList/
│   │   ├── HeroesListViewController.swift
│   │   ├── HeroesListViewModel.swift
│   │   └── HeroCell.swift
│   ├── HeroDetail/
│   │   ├── HeroDetailViewController.swift
│   │   └── HeroDetailViewModel.swift
│   └── Common/
│       ├── ImageLoader.swift
│       └── Extensions/UIView+Constraints.swift
└── Resources/
    ├── Assets.xcassets
    └── LaunchScreen.storyboard
```

## Testing

31 unit tests across all layers:

| Test Suite | Count | What It Covers |
|---|---|---|
| HeroesListViewModelTests | 6 | Pagination, loading states, refresh, error handling |
| HeroDetailViewModelTests | 3 | Detail loading, error states, initial state |
| DefaultHeroRepositoryTests | 2 | Primary/fallback data source delegation |
| ComicVineCharacterDTOMappingTests | 9 | DTO → Domain mapping, image fallback, alias parsing, nil handling |
| ComicVineCharacterDTODecodingTests | 4 | JSON decoding, null fields, list/single responses |
| HeroDetailViewControllerTests | 7 | UI state transitions, content rendering, HTML stripping |

All tests use a `MockHeroRepository` injected via protocols — no network calls in tests.

## Trade-offs and What I'd Add with More Time

- **SwiftUI** — Could use SwiftUI for the detail screen or adopt `UIHostingController` for individual components. Kept UIKit throughout for consistency and to demonstrate UIKit proficiency.
- **Persistence** — Add Core Data or SwiftData to cache heroes locally for true offline support beyond the mock fallback.
- **UI polish** — Skeleton loading placeholders, animated transitions between list and detail, hero image zoom.
- **More test coverage** — Integration tests with a local mock server, snapshot tests for UI verification, UI tests for navigation flows.
- **Coordinator pattern** — Extract navigation logic from ViewControllers into coordinators for better separation and deep linking support.

## Requirements

- Xcode 16+
- iOS 16.0+
- Swift 5.9+
