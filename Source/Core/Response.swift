//
//  Response.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// Default type of `DataResponse` returned by Alamofire, with an `AFError` `Failure` type.
public typealias AFDataResponse<Success> = DataResponse<Success, AFError>
/// Default type of `DownloadResponse` returned by Alamofire, with an `AFError` `Failure` type.
public typealias AFDownloadResponse<Success> = DownloadResponse<Success, AFError>

/// Type used to store all values associated with a serialized response of a `DataRequest` or `UploadRequest`.
public struct DataResponse<Success, Failure: Error>: Sendable where Success: Sendable, Failure: Sendable {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The data returned by the server.
    public let data: Data?

    /// The final metrics of the response.
    ///
    /// - Note: Due to `FB7624529`, collection of `URLSessionTaskMetrics` on watchOS is currently disabled.`
    ///
    public let metrics: URLSessionTaskMetrics?

    /// The time taken to serialize the response.
    public let serializationDuration: TimeInterval

    /// The result of response serialization.
    public let result: Result<Success, Failure>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Success? { result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { result.failure }

    /// Creates a `DataResponse` instance with the specified parameters derived from the response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - data:                  The `Data` returned by the server.
    ///   - metrics:               The `URLSessionTaskMetrics` of the `DataRequest` or `UploadRequest`.
    ///   - serializationDuration: The duration taken by serialization.
    ///   - result:                The `Result` of response serialization.
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                data: Data?,
                metrics: URLSessionTaskMetrics?,
                serializationDuration: TimeInterval,
                result: Result<Success, Failure>) {
        self.request = request
        self.response = response
        self.data = data
        self.metrics = metrics
        self.serializationDuration = serializationDuration
        self.result = result
    }
}

// MARK: -

extension DataResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        "\(result)"
    }

    /// The debug textual representation used when written to an output stream, which includes (if available) a summary
    /// of the `URLRequest`, the request's headers and body (if decodable as a `String` below 100KB); the
    /// `HTTPURLResponse`'s status code, headers, and body; the duration of the network and serialization actions; and
    /// the `Result` of serialization.
    public var debugDescription: String {
        guard let urlRequest = request else { return "[Request]: None\n[Result]: \(result)" }

        let requestDescription = DebugDescription.description(of: urlRequest)

        let responseDescription = response.map { response in
            let responseBodyDescription = DebugDescription.description(for: data, headers: response.headers)

            return """
            \(DebugDescription.description(of: response))
                \(responseBodyDescription.indentingNewlines())
            """
        } ?? "[Response]: None"

        let networkDuration = metrics.map { "\(String(format: "%.2f", $0.taskInterval.duration * 1000))ms" } ?? "None"

        return """
        \(requestDescription)
        \(responseDescription)
        [Network Duration]: \(networkDuration)
        [Serialization Duration]: \(String(format: "%.2f", serializationDuration * 1000))ms
        """
    }
}

// MARK: -

extension DataResponse {
    /// Evaluates the specified closure when the result of this `DataResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that does not throw. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DataResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> DataResponse<NewSuccess, Failure> {
        DataResponse<NewSuccess, Failure>(request: request,
                                          response: response,
                                          data: data,
                                          metrics: metrics,
                                          serializationDuration: serializationDuration,
                                          result: result.map(transform))
    }

    /// Evaluates the given closure when the result of this `DataResponse` is a success, passing the unwrapped result
    /// value as a parameter.
    ///
    /// Use the `tryMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A success or failure `DataResponse` depending on the result of the given closure. If this instance's
    ///            result is a failure, returns the same failure.
    public func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> DataResponse<NewSuccess, any Error> {
        DataResponse<NewSuccess, any Error>(request: request,
                                            response: response,
                                            data: data,
                                            metrics: metrics,
                                            serializationDuration: serializationDuration,
                                            result: result.tryMap(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that does not throw. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> DataResponse<Success, NewFailure> {
        DataResponse<Success, NewFailure>(request: request,
                                          response: response,
                                          data: data,
                                          metrics: metrics,
                                          serializationDuration: serializationDuration,
                                          result: result.mapError(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `tryMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func tryMapError<NewFailure: Error>(_ transform: (Failure) throws -> NewFailure) -> DataResponse<Success, any Error> {
        DataResponse<Success, any Error>(request: request,
                                         response: response,
                                         data: data,
                                         metrics: metrics,
                                         serializationDuration: serializationDuration,
                                         result: result.tryMapError(transform))
    }
}

// MARK: -

/// Used to store all data associated with a serialized response of a download request.
public struct DownloadResponse<Success, Failure: Error>: Sendable where Success: Sendable, Failure: Sendable {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The final destination URL of the data returned from the server after it is moved.
    public let fileURL: URL?

    /// The resume data generated if the request was cancelled.
    public let resumeData: Data?

    /// The final metrics of the response.
    ///
    /// - Note: Due to `FB7624529`, collection of `URLSessionTaskMetrics` on watchOS is currently disabled.`
    ///
    public let metrics: URLSessionTaskMetrics?

    /// The time taken to serialize the response.
    public let serializationDuration: TimeInterval

    /// The result of response serialization.
    public let result: Result<Success, Failure>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Success? { result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { result.failure }

    /// Creates a `DownloadResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - fileURL:               The final destination URL of the data returned from the server after it is moved.
    ///   - resumeData:            The resume `Data` generated if the request was cancelled.
    ///   - metrics:               The `URLSessionTaskMetrics` of the `DownloadRequest`.
    ///   - serializationDuration: The duration taken by serialization.
    ///   - result:                The `Result` of response serialization.
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                fileURL: URL?,
                resumeData: Data?,
                metrics: URLSessionTaskMetrics?,
                serializationDuration: TimeInterval,
                result: Result<Success, Failure>) {
        self.request = request
        self.response = response
        self.fileURL = fileURL
        self.resumeData = resumeData
        self.metrics = metrics
        self.serializationDuration = serializationDuration
        self.result = result
    }
}

// MARK: -

extension DownloadResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        "\(result)"
    }

    /// The debug textual representation used when written to an output stream, which includes the URL request, the URL
    /// response, the temporary and destination URLs, the resume data, the durations of the network and serialization
    /// actions, and the response serialization result.
    public var debugDescription: String {
        guard let urlRequest = request else { return "[Request]: None\n[Result]: \(result)" }

        let requestDescription = DebugDescription.description(of: urlRequest)
        let responseDescription = response.map(DebugDescription.description(of:)) ?? "[Response]: None"
        let networkDuration = metrics.map { "\(String(format: "%.2f", $0.taskInterval.duration * 1000))ms" } ?? "None"
        let resumeDataDescription = resumeData.map { "\($0)" } ?? "None"

        return """
        \(requestDescription)
        \(responseDescription)
        [File URL]: \(fileURL?.path ?? "None")
        [Resume Data]: \(resumeDataDescription)
        [Network Duration]: \(networkDuration)
        [Serialization Duration]: \(String(format: "%.2f", serializationDuration * 1000))ms
        """
    }
}

// MARK: -

extension DownloadResponse {
    /// Evaluates the given closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that does not throw. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DownloadResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> DownloadResponse<NewSuccess, Failure> {
        DownloadResponse<NewSuccess, Failure>(request: request,
                                              response: response,
                                              fileURL: fileURL,
                                              resumeData: resumeData,
                                              metrics: metrics,
                                              serializationDuration: serializationDuration,
                                              result: result.map(transform))
    }

    /// Evaluates the given closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `tryMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A success or failure `DownloadResponse` depending on the result of the given closure. If this
    /// instance's result is a failure, returns the same failure.
    public func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> DownloadResponse<NewSuccess, any Error> {
        DownloadResponse<NewSuccess, any Error>(request: request,
                                                response: response,
                                                fileURL: fileURL,
                                                resumeData: resumeData,
                                                metrics: metrics,
                                                serializationDuration: serializationDuration,
                                                result: result.tryMap(transform))
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that does not throw. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DownloadResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> DownloadResponse<Success, NewFailure> {
        DownloadResponse<Success, NewFailure>(request: request,
                                              response: response,
                                              fileURL: fileURL,
                                              resumeData: resumeData,
                                              metrics: metrics,
                                              serializationDuration: serializationDuration,
                                              result: result.mapError(transform))
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `tryMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: A `DownloadResponse` instance containing the result of the transform.
    public func tryMapError<NewFailure: Error>(_ transform: (Failure) throws -> NewFailure) -> DownloadResponse<Success, any Error> {
        DownloadResponse<Success, any Error>(request: request,
                                             response: response,
                                             fileURL: fileURL,
                                             resumeData: resumeData,
                                             metrics: metrics,
                                             serializationDuration: serializationDuration,
                                             result: result.tryMapError(transform))
    }
}

private enum DebugDescription {
    static func description(of request: URLRequest) -> String {
        let requestSummary = "\(request.httpMethod!) \(request)"
        let requestHeadersDescription = DebugDescription.description(for: request.headers)
        let requestBodyDescription = DebugDescription.description(for: request.httpBody, headers: request.headers)

        return """
        [Request]: \(requestSummary)
            \(requestHeadersDescription.indentingNewlines())
            \(requestBodyDescription.indentingNewlines())
        """
    }

    static func description(of response: HTTPURLResponse) -> String {
        """
        [Response]:
            [Status Code]: \(response.statusCode)
            \(DebugDescription.description(for: response.headers).indentingNewlines())
        """
    }

    static func description(for headers: HTTPHeaders) -> String {
        guard !headers.isEmpty else { return "[Headers]: None" }

        let headerDescription = "\(headers.sorted())".indentingNewlines()
        return """
        [Headers]:
            \(headerDescription)
        """
    }

    static func description(for data: Data?,
                            headers: HTTPHeaders,
                            allowingPrintableTypes printableTypes: [String] = ["json", "xml", "text"],
                            maximumLength: Int = 100_000) -> String {
        guard let data, !data.isEmpty else { return "[Body]: None" }

        guard
            data.count <= maximumLength,
            printableTypes.compactMap({ headers["Content-Type"]?.contains($0) }).contains(true)
        else { return "[Body]: \(data.count) bytes" }

        var resData = data
        if #available(iOSApplicationExtension 11.0, *) {
            if ["json"].compactMap({ headers["Content-Type"]?.contains($0) }).contains(true),
               let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
               let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
                resData = data
            }
        }
        let responseString = String(decoding: resData, as: UTF8.self)
        
        return """
        [Body]:
            \(responseString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .indentingNewlines())
        """
    }
}

extension String {
    fileprivate func indentingNewlines(by spaceCount: Int = 4) -> String {
        let spaces = String(repeating: " ", count: spaceCount)
        return replacingOccurrences(of: "\n", with: "\n\(spaces)")
    }
}
