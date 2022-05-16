// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import URLRouting
import Vapor


enum DocsRoute: String, CaseIterable {
    case builds

    static let router = Path { "docs"; parser() }
}


enum PackageRoute {
    case builds
    case maintainerInfo
    case readme
    case releases
    case show

    static let router = OneOf {
        Route(.case(Self.builds)) { Path { "builds" } }
        Route(.case(Self.maintainerInfo)) { Path { "information-for-package-maintainers" } }
        Route(.case(Self.readme)) { Path { "readme" } }
        Route(.case(Self.releases)) { Path { "releases" } }
        Route(.case(Self.show))
    }
}


enum TopLevelRoute: String, CaseIterable {
    case addAPackage = "add-a-package"
    case faq
    case packageCollections = "package-collections"
    case privacy
    case tryInPlayground = "try-package"

    static let router = Path { parser() }
}


enum SiteRoute {
    case docs(DocsRoute)
    case home
    case package(owner: String, repository: String, route: PackageRoute = .show)
    case topLevel(TopLevelRoute)

    static let router = OneOf {
        Route(.case(Self.home))

        Route(.case(Self.docs)) { DocsRoute.router }

        Route(.case(Self.package(owner:repository:route:))) {
            Path { Parse(.string) }
            Path { Parse(.string) }
            PackageRoute.router
        }

        Route(.case(Self.topLevel)) { TopLevelRoute.router }
    }
}


extension SiteRoute {
    static func handler(req: Request, route: SiteRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case .docs(.builds), .topLevel:
                let filename = try router.print(route).path.joined(separator: "/") + ".md"
                return MarkdownPage(path: req.url.path, filename).document()

            case .home:
                return try await HomeIndex.Model.query(database: req.db).map {
                    HomeIndex.View(path: req.url.path, model: $0).document()
                }.get()

            case let .package(owner: owner, repository: repository, route: .builds):
                return try await PackageController
                    .builds(req: req, owner: owner, repository: repository)

            case let .package(owner: owner, repository: repository, route: .maintainerInfo):
                return try await PackageController
                    .maintainerInfo(req: req, owner: owner, repository: repository)
                    .get()

            case let .package(owner: owner, repository: repository, route: .readme):
                return try await PackageController
                    .readme(req: req, owner: owner, repository: repository)
                    .get()

            case let .package(owner: owner, repository: repository, route: .releases):
                return try await PackageController
                    .releases(req: req, owner: owner, repository: repository)

            case let .package(owner: owner, repository: repository, route: .show):
                return try await PackageController
                    .show(req: req, owner: owner, repository: repository)
        }
    }
}
