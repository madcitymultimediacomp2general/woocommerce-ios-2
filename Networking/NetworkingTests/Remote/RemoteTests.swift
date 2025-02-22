import Combine
import XCTest
import Fakes
import TestKit

@testable import Networking


/// Remote UnitTests
///
@MainActor
final class RemoteTests: XCTestCase {

    /// Sample Request
    ///
    private let request = JetpackRequest(wooApiVersion: .mark3, method: .post, siteID: 123, path: "something", parameters: [:])

    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    /// Verifies that `enqueue:mapper:` properly wraps up the received request within an AuthenticatedRequest, with
    /// the remote credentials.
    ///
    func testEnqueueProperlyWrapsUpDataRequestsIntoAuthenticatedRequestWithCredentials() {
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let expectation = self.expectation(description: "Enqueue with Mapper")

        remote.enqueue(request, mapper: mapper) { (payload, error) in
            guard case NetworkError.notFound? = error,
                  let receivedRequest = network.requestsForResponseData.first as? JetpackRequest
            else {
                XCTFail()
                return
            }

            XCTAssertNil(payload)
            XCTAssert(network.requestsForResponseData.count == 1)
            XCTAssertEqual(receivedRequest.method, self.request.method)
            XCTAssertEqual(receivedRequest.path, self.request.path)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `enqueue:mapper:` with `Result` callback properly wraps up the received
    /// request within an AuthenticatedRequest, with the remote credentials.
    ///
    func testEnqueueWithResultProperlyWrapsUpDataRequestsIntoAuthenticatedRequestWithCredentials() throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        // When
        var result: Result<Any, Error>?
        waitForExpectation { expectation in
            remote.enqueue(request, mapper: mapper) { aResult in
                result = aResult
                expectation.fulfill()
            }
        }

        // Then
        let receivedRequest = try XCTUnwrap(network.requestsForResponseData.first as? JetpackRequest)

        XCTAssertTrue(try XCTUnwrap(result).isFailure)
        XCTAssert(network.requestsForResponseData.count == 1)
        XCTAssertEqual(receivedRequest.method, request.method)
        XCTAssertEqual(receivedRequest.path, request.path)
    }

    /// Verifies that `enqueuePublisher:` properly wraps up the received request within an AuthenticatedRequest, with
    /// the remote credentials.
    ///
    func test_enqueuePublisher_wraps_up_request_into_authenticated_request_with_credentials() throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        // When
        let result = waitFor { promise in
            remote.enqueue(self.request, mapper: mapper).sink { result in
                promise(result)
            }.store(in: &self.cancellables)
        }

        // Then
        let error = try XCTUnwrap(result.failure)
        guard case NetworkError.notFound = error,
              let receivedRequest = network.requestsForResponseData.first as? JetpackRequest
        else {
            XCTFail()
            return
        }

        XCTAssertEqual(network.requestsForResponseData.count, 1)
        XCTAssertEqual(receivedRequest.method, request.method)
        XCTAssertEqual(receivedRequest.path, request.path)
    }

    /// Verifies that `enqueue:mapper:` relays any received payload over to the Mapper.
    ///
    func testEnqueueWithMapperProperlyRelaysReceivedPayloadToMapper() {
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        let expectation = self.expectation(description: "Enqueue with Mapper")

        network.simulateResponse(requestUrlSuffix: "something", filename: "order")

        remote.enqueue(request, mapper: mapper) { (payload, error) in
            XCTAssertEqual(mapper.input, Loader.contentsOf("order"))
            XCTAssertNotNil(mapper.input)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `enqueue:mapper:` with `Result` callback relays any received payload over to the Mapper.
    ///
    func testEnqueueWithMapperAndResultCallbackProperlyRelaysReceivedPayloadToMapper() {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        network.simulateResponse(requestUrlSuffix: "something", filename: "order")

        // When
        waitForExpectation { expectation in
            remote.enqueue(request, mapper: mapper) { _ in
                expectation.fulfill()
            }
        }

        // Then
        XCTAssertEqual(mapper.input, Loader.contentsOf("order"))
        XCTAssertNotNil(mapper.input)
    }

    /// Verifies that `enqueuePublisher` relays any received payload over to the Mapper.
    ///
    func test_enqueuePublisher_relays_received_payload_to_mapper() {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        network.simulateResponse(requestUrlSuffix: "something", filename: "order")

        // When
        waitForExpectation { expectation in
            remote.enqueue(request, mapper: mapper).sink { _ in
                expectation.fulfill()
            }.store(in: &cancellables)
        }

        // Then
        XCTAssertEqual(mapper.input, Loader.contentsOf("order"))
        XCTAssertNotNil(mapper.input)
    }

    /// Verifies that `enqueue:` posts a `RemoteDidReceiveJetpackTimeoutError` Notification whenever the backend returns a
    /// Request Timeout error.
    ///
    func testEnqueueRequestWithoutMapperPostJetpackTimeoutNotificationWhenTheResponseContainsTimeoutError() async throws {
        let network = MockNetwork()
        let remote = Remote(network: network)

        let expectationForNotification = expectation(forNotification: .RemoteDidReceiveJetpackTimeoutError, object: nil, handler: nil)
        network.simulateResponse(requestUrlSuffix: "something", filename: "timeout_error")

        do {
            let _: String = try await remote.enqueue(request)
        } catch {
            let error = try XCTUnwrap(error as? DotcomError)
            XCTAssertEqual(error, .requestFailed)
        }

        wait(for: [expectationForNotification], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `enqueue:mapper:` posts a `RemoteDidReceiveJetpackTimeoutError` Notification whenever the backend returns a
    /// Request Timeout error.
    ///
    func testEnqueueRequestWithMapperPostsJetpackTimeoutNotificationWhenTheResponseContainsTimeoutError() {
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        let expectationForNotification = expectation(forNotification: .RemoteDidReceiveJetpackTimeoutError, object: nil, handler: nil)
        let expectationForRequest = expectation(description: "Request")

        network.simulateResponse(requestUrlSuffix: "something", filename: "timeout_error")

        remote.enqueue(request, mapper: mapper) { (payload, error) in
            XCTAssertNil(payload)
            XCTAssert(error is DotcomError)
            expectationForRequest.fulfill()
        }

        wait(for: [expectationForNotification, expectationForRequest], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `enqueue:mapper:` (with `Result`) posts a `RemoteDidReceiveJetpackTimeoutError`
    /// Notification whenever the backend returns a Request Timeout error.
    ///
    func testEnqueueRequestWithResultWithMapperPostsJetpackTimeoutNotificationWhenTheResponseContainsTimeoutError() throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        network.simulateResponse(requestUrlSuffix: "something", filename: "timeout_error")

        // When
        let expectationForNotification = expectation(forNotification: .RemoteDidReceiveJetpackTimeoutError, object: nil, handler: nil)
        let expectationForRequest = expectation(description: "Request")

        var result: Result<Any, Error>?
        remote.enqueue(request, mapper: mapper) { aResult in
            result = aResult
            expectationForRequest.fulfill()
        }

        wait(for: [expectationForNotification, expectationForRequest], timeout: Constants.expectationTimeout)

        // Then
        XCTAssertTrue(try XCTUnwrap(result).isFailure)
        XCTAssertTrue(try XCTUnwrap(result?.failure) is DotcomError)
    }

    /// Verifies that `enqueuePublisher` posts a `RemoteDidReceiveJetpackTimeoutError` Notification whenever the backend returns a Request Timeout error.
    ///
    func test_enqueuePublisher_posts_Jetpack_timeout_notification_when_the_response_contains_timeout_error() throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)

        network.simulateResponse(requestUrlSuffix: "something", filename: "timeout_error")

        // When
        let expectationForNotification = expectation(forNotification: .RemoteDidReceiveJetpackTimeoutError, object: nil, handler: nil)
        let result: Result<Any, Error> = waitFor { promise in
            remote.enqueue(self.request, mapper: mapper).sink { result in
                promise(result)
            }.store(in: &self.cancellables)
        }
        wait(for: [expectationForNotification], timeout: Constants.expectationTimeout)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.failure as? DotcomError, DotcomError.requestFailed)
    }

    /// Verifies that dotcom v1.1 request parses DotcomError
    ///
    func test_dotcom_request_v1_1_parses_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .mark1_1, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        await assertThrowsError({ _ = try await remote.enqueue(request, mapper: mapper)}, errorAssert: { $0 is DotcomError })
    }

    /// Verifies that dotcom v1.1 request doesn't parse WordPressApiError
    ///
    func test_dotcom_request_v1_1_does_not_parse_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .mark1_1, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "error-wp-rest-forbidden")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)
        XCTAssertNotNil(result)
    }

    /// Verifies that dotcom v1.2 request parses DotcomError
    ///
    func test_dotcom_request_v1_2_parses_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .mark1_2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        await assertThrowsError({ _ = try await remote.enqueue(request, mapper: mapper)}, errorAssert: { $0 is DotcomError })
    }

    /// Verifies that dotcom v1.2 request doesn't parse WordPressApiError
    ///
    func test_dotcom_request_v1_2_does_not_parse_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .mark1_2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "error-wp-rest-forbidden")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }

    /// Verifies that dotcom wpcom v2 request parses WordPressApiError
    ///
    func test_dotcom_request_wpcom_v2_parses_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .wpcomMark2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "error-wp-rest-forbidden")

        await assertThrowsError({ _ = try await remote.enqueue(request, mapper: mapper)}, errorAssert: { $0 is WordPressApiError })
    }

    /// Verifies that dotcom wpcom v2 request doesn't parse DotcomError
    ///
    func test_dotcom_request_wpcom_v2_does_not_parse_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .wpcomMark2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }

    /// Verifies that dotcom wp v2 request parses WordPressApiError
    ///
    func test_dotcom_request_wp_v2_parses_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .wpMark2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "error-wp-rest-forbidden")

        await assertThrowsError({ _ = try await remote.enqueue(request, mapper: mapper)}, errorAssert: { $0 is WordPressApiError })
    }

    /// Verifies that dotcom wp v2 request doesn't parse DotcomError
    ///
    func test_dotcom_request_wp_v2_does_not_parse_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = DotcomRequest(wordpressApiVersion: .wpMark2, method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }

    /// Verifies that Jetpack request parses DotcomError
    ///
    func test_jetpack_request_parses_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = JetpackRequest(wooApiVersion: .mark3, method: .post, siteID: 123, path: "mock", parameters: [:])

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        await assertThrowsError({ _ = try await remote.enqueue(request, mapper: mapper)}, errorAssert: { $0 is DotcomError })
    }

    /// Verifies that Jetpack request doesn't parse WordPressApiError
    ///
    func test_jetpack_request_does_not_parse_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = JetpackRequest(wooApiVersion: .mark3, method: .post, siteID: 123, path: "mock", parameters: [:])

        network.simulateResponse(requestUrlSuffix: "mock", filename: "error-wp-rest-forbidden")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }

    /// Verifies that RESTRequest request doesn't parse WordPressApiError
    ///
    func test_wordpress_org_request_does_not_parse_wordpress_api_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = RESTRequest(siteURL: "https://example.com", method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }

    /// Verifies that RESTRequest request doesn't parse DotcomError
    ///
    func test_wordpress_org_request_does_not_parse_dotcom_error() async throws {
        // Given
        let network = MockNetwork()
        let mapper = DummyMapper()
        let remote = Remote(network: network)
        let request = RESTRequest(siteURL: "https://example.com", method: .get, path: "mock")

        network.simulateResponse(requestUrlSuffix: "mock", filename: "timeout_error")

        // When
        let result = try await remote.enqueue(request, mapper: mapper)

        // Then
        XCTAssertNotNil(result)
    }
}


/// Dummy Mapper: Useful only for Remote UnitTests
///
private class DummyMapper: Mapper {

    /// Contains the last received `response` (via the map method).
    ///
    var input: Data?

    func map(response: Data) throws -> Any {
        input = response
        return response
    }
}
