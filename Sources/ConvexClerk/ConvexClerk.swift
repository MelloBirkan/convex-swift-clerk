import Foundation
import Clerk
import ConvexMobile

public struct ClerkCredentials: Sendable {
  public let userId: String
  public let idToken: String
  
  public init(userId: String, idToken: String) {
    self.userId = userId
    self.idToken = idToken
  }
}

public enum ClerkAuthError: Error, LocalizedError, Sendable {
  case clerkNotLoaded
  case noActiveSession
  case tokenRetrievalFailed(String)
  case signInTimeout
  
  public var errorDescription: String? {
    switch self {
    case .clerkNotLoaded:
      return "Clerk SDK is not loaded. Initialize Clerk with Clerk.configure(publishableKey:) first."
    case .noActiveSession:
      return "No active Clerk session found."
    case .tokenRetrievalFailed(let reason):
      return "Failed to retrieve Clerk token: \(reason)"
    case .signInTimeout:
      return "Timed out waiting for Clerk sign-in completion."
    }
  }
}

public class ClerkAuthProvider: AuthProvider {
  public typealias T = ClerkCredentials
  
  private let jwtTemplate: String
  private let signInTimeout: TimeInterval
  
  public init(jwtTemplate: String = "convex", signInTimeout: TimeInterval = 120) {
    self.jwtTemplate = jwtTemplate
    self.signInTimeout = signInTimeout
  }
  
  public func login() async throws -> ClerkCredentials {
    try await ensureClerkLoaded()

    do {
      return try await fetchCredentials()
    } catch ClerkAuthError.noActiveSession {
      // Fall through to waiting for the user to complete sign-in.
    }

    try await waitForSignInCompletion()
    return try await fetchCredentials()
  }
  
  public func loginFromCache() async throws -> ClerkCredentials {
    try await ensureClerkLoaded()
    return try await fetchCredentials()
  }
  
  public func logout() async throws {
    try await Clerk.shared.signOut()
  }
  
  public func extractIdToken(from authResult: ClerkCredentials) -> String {
    return authResult.idToken
  }

  public func extractIdToken(authResult: ClerkCredentials) -> String {
    extractIdToken(from: authResult)
  }
  
  private func ensureClerkLoaded() async throws {
    let isLoaded = await MainActor.run { Clerk.shared.isLoaded }
    guard isLoaded else {
      throw ClerkAuthError.clerkNotLoaded
    }
  }
  
  private func waitForSignInCompletion() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        for await event in await Clerk.shared.authEventEmitter.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            return
          case .signedOut:
            continue
          @unknown default:
            continue
          }
        }
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(self.signInTimeout * 1_000_000_000))
        throw ClerkAuthError.signInTimeout
      }
      
      try await group.next()
      group.cancelAll()
    }
  }
  
  private func fetchCredentials() async throws -> ClerkCredentials {
    guard let user = await MainActor.run(body: { Clerk.shared.user }) else {
      throw ClerkAuthError.noActiveSession
    }
    guard let session = await MainActor.run(body: { Clerk.shared.session }) else {
      throw ClerkAuthError.noActiveSession
    }
    
    guard let token = try await session.getToken(.init(template: jwtTemplate)) else {
      throw ClerkAuthError.tokenRetrievalFailed("Token returned nil for template '\(jwtTemplate)'")
    }
    
    return ClerkCredentials(userId: user.id, idToken: token.jwt)
  }
}
