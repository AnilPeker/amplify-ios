//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSCore

public class AmplifyAWSCredentialsProvider: CredentialsProvider {

    public func getCredentials() async throws -> AWSCredentials {
        try await withCheckedThrowingContinuation { continuation in
            _  = Amplify.Auth.fetchAuthSession { result in
                do {
                    let session = try result.get()
                    if let awsCredentialsProvider = session as? AuthAWSCredentialsProvider {
                        let credentials = try awsCredentialsProvider.getAWSCredentials().get()
                        continuation.resume(with: .success(credentials.toAWSSDKCredentials()))
                    } else {
                        let error = AuthError.unknown("Auth session does not include AWS credentials information")
                        continuation.resume(with: .failure(error))
                    }
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }
    
    public func getCredentials() throws -> Future<AWSCredentials> {
        let future = Future<AWSCredentials>()
        _  = Amplify.Auth.fetchAuthSession { result in
            
            do {
                let session = try result.get()
                if let awsCredentialsProvider = session as? AuthAWSCredentialsProvider {
                    let credentials = try awsCredentialsProvider.getAWSCredentials().get()
                    future.fulfill(credentials.toAWSSDKCredentials())
                } else {
                    let error = AuthError.unknown("Auth session does not include AWS credentials information")
                    future.fail(error)
                }
            } catch {
                future.fail(error)
            }
        }
        return future
    }
}

extension AuthAWSCredentials {
    func toAWSCoreCredentials() -> AWSCredentials {
        if let tempCredentials = self as? AuthAWSTemporaryCredentials {
            return AWSCredentials(accessKey: tempCredentials.accessKey,
                                  secretKey: tempCredentials.secretKey,
                                  sessionKey: tempCredentials.sessionKey,
                                  expiration: tempCredentials.expiration)
        } else {
            return AWSCredentials(accessKey: accessKey,
                                  secretKey: secretKey,
                                  sessionKey: nil,
                                  expiration: nil)
        }
    }
}
