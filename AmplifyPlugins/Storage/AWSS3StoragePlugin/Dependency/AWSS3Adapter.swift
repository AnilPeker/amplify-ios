//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3

/// The class conforming to AWSS3Behavior which uses an instance of the AWSS3 to perform its methods.
/// This class acts as a wrapper to expose AWSS3 functionality through an instance over a singleton,
/// and allows for mocking in unit tests. The methods contain no other logic other than calling the
/// same method using the AWSS3 instance.
class AWSS3Adapter: AWSS3Behavior {
    let awsS3: AWSS3

    init(_ awsS3: AWSS3) {
        self.awsS3 = awsS3
    }

    /// Lists objects in the bucket specified by `request`.
    /// - Parameters:
    ///   - request: request identifying bucket and options
    ///   - completion: handle which return a result with list of items
    func listObjectsV2(_ request: AWSS3ListObjectsV2Request, completion: @escaping (Result<StorageListResult, StorageError>) -> Void) {
        let input = ListObjectsV2Input(prefix: request.prefix,
                                       bucket: request.bucket,
                                       continuationToken: request.continuationToken,
                                       delimiter: request.delimiter,
                                       maxKeys: request.maxKeys,
                                       startAfter: request.startAfter)
        awsS3.listObjectsV2(input: input) { result in
            switch(result) {
            case .success(let response):
                let contents: S3BucketContents = response.contents ?? []
                do {
                    let items = try contents.map {
                        try StorageListResult.Item(s3Object: $0, prefix: request.prefix ?? "")
                    }
                    let listResult = StorageListResult(items: items)
                    completion(.success(listResult))
                } catch {
                    completion(.failure(StorageError(error: error)))
                }
            case .failure(let error):
                completion(.failure(error.storageError))
            }
        }
    }
    
    /// Creates a MultipartUpload
    /// - Parameters:
    ///   - request: request
    ///   - completion: handler which returns a result with uploadId
    func createMultipartUpload(_ request: CreateMultipartUploadRequest, completion: @escaping (Result<AWSS3CreateMultipartUploadResponse, StorageError>) -> Void) {
        let input = CreateMultipartUploadInput(bucket: request.bucket,
                                               cacheControl: request.cacheControl,
                                               contentDisposition: request.contentDisposition,
                                               contentEncoding: request.contentEncoding,
                                               contentLanguage: request.contentLanguage,
                                               contentType: request.contentType,
                                               expires: request.expires,
                                               key: request.key,
                                               metadata: request.metadata)
        
        awsS3.createMultipartUpload(config: config, input: input) { result in
            switch result {
            case .success(let response):
                guard let bucket = response.bucket, let key = response.key, let uploadId = response.uploadId else {
                    completion(.failure(StorageError.unknown("Invalid response for creating multipart upload", nil)))
                    return
                }
                completion(.success(AWSS3CreateMultipartUploadResponse(bucket: bucket, key: key, uploadId: uploadId)))
            case .failure(let error):
                completion(.failure(error.storageError))
            }
        }
    }

    /// Deletes object identify by request.
    /// - Parameter request: request identifying object
    /// - Returns: task
    public func deleteObject(_ request: AWSS3DeleteObjectRequest) -> AWSTask<AWSS3DeleteObjectOutput> {
        return awsS3.deleteObject(request)
    }
    
    /// Completed a MultipartUpload
    /// - Parameters:
    ///   - request: request which includes uploadId
    ///   - completion: handler which returns a result with object details
    func completeMultipartUpload(_ request: AWSS3CompleteMultipartUploadRequest, completion: @escaping (Result<AWSS3CompleteMultipartUploadResponse, StorageError>) -> Void) {
        let parts = request.parts.map {
            S3ClientTypes.CompletedPart(eTag: $0.eTag, partNumber: $0.partNumber)
        }
        let completedMultipartUpload = S3ClientTypes.CompletedMultipartUpload(parts: parts)
        let input = CompleteMultipartUploadInput(bucket: request.bucket, key: request.key, multipartUpload: completedMultipartUpload, uploadId: request.uploadId)
        awsS3.completeMultipartUpload(config: config, input: input) { result in
            switch result {
            case .success(let response):
                guard let eTag = response.eTag else {
                    completion(.failure(StorageError.unknown("Invalid response for completing multipart upload", nil)))
                    return
                }
                completion(.success(AWSS3CompleteMultipartUploadResponse(bucket: request.bucket, key: request.key, eTag: eTag)))
            case .failure(let error):
                completion(.failure(error.storageError))
            }
        }
    }
    
    /// Aborts a MultipartUpload
    /// - Parameters:
    ///   - request: request which includes uploadId
    ///   - completion: handler which indicates when the operation is done
    func abortMultipartUpload(_ request: AWSS3AbortMultipartUploadRequest, completion: @escaping (Result<Void, StorageError>) -> Void) {
        let input = AbortMultipartUploadInput(bucket: request.bucket, key: request.key, uploadId: request.uploadId)
        awsS3.abortMultipartUpload(input: input) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error.storageError))
            }
        }
    }
    
    /// Instance of S3 service.
    /// - Returns: S3 service instance.
    public func getS3() -> AWSS3 {
        return awsS3
    }
}
