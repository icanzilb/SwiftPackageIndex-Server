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
}


enum PackageRoute {
    case documentation(reference: String, fragment: DocumentationFragment, path: [String])
    case show
    case staticPath(StaticPathRoute)

    static let router = OneOf {
        Route(.case(Self.documentation)) {
            Path { Parse(.string) }
            Path { DocumentationFragment.parser() }
            Many { Path { Parse(.string) } }
        }
        Route(.case(Self.show))
        Route(.case(Self.staticPath)) { Path { StaticPathRoute.parser() } }
    }

    enum DocumentationFragment: String, CaseIterable {
        case css
        case data
        case documentation
        case js
        case themeSettings = "theme-settings.json"
    }

    enum StaticPathRoute: String, CaseIterable {
        case builds
        case maintainerInfo = "information-for-package-maintainers"
        case readme
        case releases
    }
}


enum SiteRoute {
    case docs(DocsRoute)
    case home
    case package(owner: String, repository: String, route: PackageRoute = .show)
    case staticPath(StaticPathRoute)

    static let router = OneOf {
        Route(.case(Self.home))

        Route(.case(Self.docs)) { Path { "docs"; DocsRoute.parser() } }

        Route(.case(Self.package(owner:repository:route:))) {
            Path { Parse(.string) }
            Path { Parse(.string) }
            PackageRoute.router
        }

        Route(.case(Self.staticPath)) { Path { StaticPathRoute.parser() } }
    }

    enum StaticPathRoute: String, CaseIterable {
        case addAPackage = "add-a-package"
        case faq
        case packageCollections = "package-collections"
        case privacy
        case tryInPlayground = "try-package"
    }
}


extension SiteRoute {
    static func handler(req: Request, route: SiteRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case .docs(.builds), .staticPath:
                let filename = try router.print(route).path.joined(separator: "/") + ".md"
                return MarkdownPage(path: req.url.path, filename).document()

            case .home:
                return try await HomeIndex.Model.query(database: req.db).map {
                    HomeIndex.View(path: req.url.path, model: $0).document()
                }.get()

            case let .package(owner: owner, repository: repository, route: packageRoute):
                return try await PackageRoute.handler(req: req, owner: owner, repository: repository, route: packageRoute)

        }
    }
}


extension PackageRoute {
    static func handler(req: Request, owner: String, repository: String, route: PackageRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case let .documentation(reference: reference, fragment: fragment, path: path):
                return try await PackageController.documentation(req: req, owner: owner, repository: repository, reference: reference, fragment: fragment, path: path)

            case .show:
                return try await PackageController
                    .show(req: req, owner: owner, repository: repository)

            case .staticPath(let staticPathRoute):
                switch staticPathRoute {
                    case .builds:
                        return try await PackageController
                            .builds(req: req, owner: owner, repository: repository)

                    case .maintainerInfo:
                        return try await PackageController
                            .maintainerInfo(req: req, owner: owner, repository: repository)
                            .get()

                    case .readme:
                        return try await PackageController
                            .readme(req: req, owner: owner, repository: repository)
                            .get()

                    case .releases:
                        return try await PackageController
                            .releases(req: req, owner: owner, repository: repository)
                }
        }
    }
}
