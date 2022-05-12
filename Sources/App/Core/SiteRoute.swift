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


enum SiteRoute {
    case docs(DocsRoute)
    case home
    case topLevel(TopLevelRoute)
}


enum DocsRoute: String, CaseIterable {
    case builds
}


enum TopLevelRoute: String, CaseIterable {
    case addAPackage = "add-a-package"
    case faq
    case packageCollections = "package-collections"
    case privacy
    case tryInPlayground = "try-package"
}


extension SiteRoute {
    static let router = OneOf {
        Route(.case(SiteRoute.home))

        Route(.case(SiteRoute.docs)) {
            Path {
                "docs"
                DocsRoute.parser()
            }
        }

        Route(.case(SiteRoute.topLevel)) { Path { TopLevelRoute.parser() } }
    }

    static func handler(req: Request, route: SiteRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case .docs(.builds), .topLevel:
                let filename = try router.print(route).path.joined(separator: "/") + ".md"
                return MarkdownPage(path: req.url.path, filename).document()

            case .home:
                return try await HomeIndex.Model.query(database: req.db).map {
                    HomeIndex.View(path: req.url.path, model: $0).document()
                }.get()
        }
    }
}
