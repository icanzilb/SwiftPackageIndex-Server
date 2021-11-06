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

import Basics
import PackageCollectionsModel
import PackageCollectionsSigning
import Vapor


typealias SignedCollection = PackageCollectionSigning.Model.SignedCollection


extension PackageCollection {

    static func sign(eventLoop: EventLoop, collection: PackageCollection) -> EventLoopFuture<SignedCollection> {
        guard let privateKey = Current.collectionSigningPrivateKey() else {
            return eventLoop.makeFailedFuture(AppError.envVariableNotSet("COLLECTION_SIGNING_PRIVATE_KEY"))
        }

        let signedCollection = eventLoop.makePromise(of: SignedCollection.self)
        signer.sign(collection: collection,
                    certChainPaths: [
                        certsDir.appendingPathComponent("package_collections_dev.cer"),
                        certsDir.appendingPathComponent("AppleWWDRCAG3.cer"),
                        certsDir.appendingPathComponent("AppleIncRootCertificate.cer")
                    ],
                    privateKeyPEM: privateKey) { result in
            switch result {
                case .success(let signed):
                    signedCollection.succeed(signed)
                case .failure(let error):
                    signedCollection.fail(error)
            }
        }
        return signedCollection.futureResult
    }

    static func validate(eventLoop: EventLoop, signedCollection: SignedCollection) -> EventLoopFuture<Bool> {
        let validation = eventLoop.makePromise(of: Bool.self)
        signer.validate(signedCollection: signedCollection) { result in
            switch result {
                case .success:
                    validation.succeed(true)
                case .failure(let error):
                    validation.fail(error)
            }
        }
        return validation.futureResult
    }

    static let certsDir = URL(fileURLWithPath: Current.fileManager.workingDirectory())
        .appendingPathComponent("Resources")
        .appendingPathComponent("Certs")

    static let signer = PackageCollectionSigning(
        trustedRootCertsDir: certsDir,
        additionalTrustedRootCerts: nil,
        observabilityScope: .ignored,
        callbackQueue: DispatchQueue.global()
    )

}


// FIXME: make private
extension ObservabilityScope {
    static var logged: ObservabilityScope {
        ObservabilitySystem { _, diagnostic in print(diagnostic) }.topScope
    }

    static var ignored: ObservabilityScope {
        ObservabilitySystem { _, _ in }.topScope
    }
}
