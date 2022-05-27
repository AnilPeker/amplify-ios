//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3

/// The class confirming to AWSS3PreSignedURLBuilderBehavior which uses an instance of the AWSS3PreSignedURLBuilder to
/// perform its methods. This class acts as a wrapper to expose AWSS3PreSignedURLBuilder functionality through an
/// instance over a singleton, and allows for mocking in unit tests. The methods contain no other logic other than
/// calling the same method using the AWSS3PreSignedURLBuilder instance.
class AWSS3PreSignedURLBuilderAdapter: AWSS3PreSignedURLBuilderBehavior {

    let preSignedURLBuilder: AWSS3PreSignedURLBuilder

    /// Creates a pre-signed URL builder.
    /// - Parameter preSignedURLBuilder: Builder which can create a pre-signed URL.
    public init(_ preSignedURLBuilder: AWSS3PreSignedURLBuilder) {
        self.preSignedURLBuilder = preSignedURLBuilder
    }

    /// Gets pre-signed URL.
    /// - Returns: Pre-Signed URL
    func getPreSignedURL(key: String, signingOperation: AWSS3SigningOperation, expires: Int64? = nil) -> URL? {
        let expiresDate = Date(timeIntervalSinceNow: Double(expires ?? defaultExpiration))
        let expiration = Int64(expiresDate.timeIntervalSinceNow)
        var preSignedUrl: URL?
        
        let group = DispatchGroup()
        
        let setValue: (URL?) -> Void = {
            preSignedUrl = $0
            group.leave()
        }
        
        group.enter()
        Task {
            do {
                switch signingOperation {
                case .getObject:
                    let input = GetObjectInput(bucket: bucket, key: key)
                    let value = try await input.presignURL(config: config, expiration: expiration)
                    setValue(value)
                case .putObject:
                    let input = PutObjectInput(bucket: bucket, key: key)
                    let value = try await input.presignURL(config: config, expiration: expiration)
                    setValue(value)
                case .uploadPart(let partNumber, let uploadId):
                    let input = UploadPartInput(bucket: bucket, key: key, partNumber: partNumber, uploadId: uploadId)
                    let value = try await input.presign(config: config, expiration: expiration)?.endpoint.url
                    setValue(value)
                }
            } catch {
                setValue(nil)
                logger.error(error: error)
            }
        }
        
        group.wait()
        
        return urlWithEscapedToken(preSignedUrl)
    }

    private func urlWithEscapedToken(_ url: URL?) -> URL? {
        print("Received URL: \(url?.absoluteString ?? "nil")")
        guard let url = url,
              var components = URLComponents(string: url.absoluteString),
              var token = components.queryItems?.first(where: { $0.name == "X-Amz-Security-Token" }) else {
                  return nil
              }
        token.value = token.value?.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        components.port = nil
        components.percentEncodedQueryItems?.removeAll(where: { $0.name == "X-Amz-Security-Token" })
        components.percentEncodedQueryItems?.append(token)
        return components.url
    }
}
