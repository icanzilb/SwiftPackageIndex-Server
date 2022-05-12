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
    case show(owner: String, repository: String)

    static let router = OneOf {
        Route(.case(Self.show(owner:repository:))) {
            Path {
                Parse(.string)
                Parse(.string)
            }
        }
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
    case package(PackageRoute)
    case topLevel(TopLevelRoute)

    static let router = OneOf {
        Route(.case(Self.home))

        Route(.case(Self.docs)) { DocsRoute.router }

        Route(.case(Self.package)) { PackageRoute.router }

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

            case let .package(.show(owner: owner, repository: repository)):
                return try await PackageController()
                    .show(req: req, owner: owner, repository: repository)
        }
    }
}
