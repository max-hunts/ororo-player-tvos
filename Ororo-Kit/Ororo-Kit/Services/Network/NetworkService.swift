//
//  NetworkService.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import Foundation

public typealias NetworkHandler<T> = (T) -> Void
public typealias NetworkErrorHandler = (Error) -> Void

public enum Result<Value> {
    case success(Value)
    case error(Error)
}

public protocol NetworkRequestsService {

    func request<T>(with endpoint: Endpoint,
                    onSuccess: @escaping NetworkHandler<T>,
                    onError: @escaping NetworkErrorHandler) where T: Decodable

    func request(with endpoint: Endpoint,
                 completion: @escaping NetworkHandler<Result<Data>>)
}

public final class NetworkService: NetworkRequestsService {

    // MARK: - Properties
    private let requestBuilder: RequestBuilder
    private let session = URLSession(configuration: .default,
                                     delegate: nil,
                                     delegateQueue: .main)

    // MARK: - Life cycle
    public init(requestBuilder: RequestBuilder) {
        self.requestBuilder = requestBuilder
    }

    // MARK: - NetworkService
    public func request<T>(with endpoint: Endpoint,
                           onSuccess: @escaping NetworkHandler<T>,
                           onError: @escaping NetworkErrorHandler)
        where T: Decodable {

            request(with: endpoint) { (response) in

                switch response {
                case .success(let data):
                    do {
                        let model: T = try data.decoded()
                        DispatchQueue.main.async {
                            onSuccess(model)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            if let jsonPayload = String(data: data, encoding: .utf8) {
                                logDebug(jsonPayload)
                            }
                            onError(error)
                        }
                    }
                case .error(let error):
                    DispatchQueue.main.async {
                        onError(error)
                    }
                }
            }
    }

    public func request(with endpoint: Endpoint,
                        completion: @escaping NetworkHandler<Result<Data>>) {
        guard let url = URL(string: endpoint.path) else {
            logFatal("[NetworkService] Invalid url")
        }

        let urlRequest = requestBuilder.buildRequest(for: url)
        let task = session.dataTask(with: urlRequest) { (data, response, error) in

            if let error = error {
                DispatchQueue.main.async {
                    completion(.error(error))
                }
            } else if response != nil, let data = data {
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            } else {
                logFatal("[NetworkService] Unexpected case. No error found, but either data or response is nil")
            }
        }
        task.resume()
    }
}
