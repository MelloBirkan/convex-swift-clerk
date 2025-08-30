// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import Clerk
import ConvexMobile

public struct ClerkCredentials {
  public let userId: String
  public let idToken: String
}

public class ClerkAuthProvider: AuthProvider {
  private let jwtTemplate: String
  
  public init(jwtTemplate: String = "convex") {
    self.jwtTemplate = jwtTemplate
  }
  
  public func login() async throws -> ClerkCredentials {
    let isLoaded = await MainActor.run { Clerk.shared.isLoaded }
    guard isLoaded else {
      throw NSError(domain: "ClerkAuthProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Clerk not loaded"])
    }
    
    if let creds = try await fetchCredentialsIfSignedIn() {
      return creds
    }
    
    try await waitUntilSignedIn()
    
    guard let creds = try await fetchCredentialsIfSignedIn() else {
      throw NSError(domain: "ClerkAuthProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain Clerk token after sign-in"])
    }
    return creds
  }
  
  public func loginFromCache() async throws -> ClerkCredentials {
    let isLoaded = await MainActor.run { Clerk.shared.isLoaded }
    guard isLoaded else {
      throw NSError(domain: "ClerkAuthProvider", code: 3, userInfo: [NSLocalizedDescriptionKey: "Clerk not loaded"])
    }
    guard let creds = try await fetchCredentialsIfSignedIn() else {
      throw NSError(domain: "ClerkAuthProvider", code: 4, userInfo: [NSLocalizedDescriptionKey: "No signed-in Clerk session found"])
    }
    return creds
  }
  
  public func extractIdToken(from authResult: ClerkCredentials) -> String {
    return authResult.idToken
  }
  
  public typealias T = ClerkCredentials
  
  public func logout() async throws {
    try await Clerk.shared.signOut()
  }
  
  private func waitUntilSignedIn() async throws {
    let deadline = Date().addingTimeInterval(120)
    while Date() < deadline {
      let hasUser = await MainActor.run { Clerk.shared.user != nil }
      if hasUser { return }
      try await Task.sleep(nanoseconds: 250_000_000)
    }
    throw NSError(domain: "ClerkAuthProvider", code: 6, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for Clerk sign-in"])
  }
  
  private func fetchCredentialsIfSignedIn() async throws -> ClerkCredentials? {
    guard let user = await MainActor.run(body: { Clerk.shared.user }) else { return nil }
    guard let session = await MainActor.run(body: { Clerk.shared.session }) else { return nil }
    
    if let token = try? await session.getToken(Session.GetTokenOptions(template: jwtTemplate)) {
      return ClerkCredentials(userId: user.id, idToken: token.jwt)
    }
    
    throw NSError(domain: "ClerkAuthProvider", code: 7, userInfo: [NSLocalizedDescriptionKey: "Clerk token API unavailable; update to your SDK's token retrieval method"])
  }
}