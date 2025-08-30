import XCTest
@testable import ConvexClerk

final class ConvexClerkTests: XCTestCase {
  func testInitialization() throws {
    let provider = ClerkAuthProvider()
    XCTAssertNotNil(provider)
  }
  
  func testInitializationWithCustomTemplate() throws {
    let provider = ClerkAuthProvider(jwtTemplate: "custom-template")
    XCTAssertNotNil(provider)
  }
}