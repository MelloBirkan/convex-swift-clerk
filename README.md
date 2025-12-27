# ConvexClerk

A Swift package that provides seamless Clerk authentication integration for [Convex Swift](https://github.com/get-convex/convex-swift) applications.

## Overview

ConvexClerk bridges [Clerk's iOS SDK](https://github.com/clerk/clerk-ios) with [Convex's Swift client](https://github.com/get-convex/convex-swift), allowing you to authenticate users via Clerk and automatically manage JWT tokens for Convex backend calls. The library implements Convex's `AuthProvider` protocol, handling token generation, session management, and authentication state transitions.

## Features

- Implements `AuthProvider` protocol for `ConvexClientWithAuth`
- Automatic JWT token generation using Clerk's JWT templates
- Support for login, cached login, and logout flows
- Configurable JWT template names and sign-in timeouts
- Async/await API with structured concurrency
- Comprehensive error handling with `ClerkAuthError`

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS      | 17.0+           |
| macOS    | 14.0+           |
| Swift    | 5.9+            |

### Dependencies

- [Convex Swift](https://github.com/get-convex/convex-swift) >= 0.5.5
- [Clerk iOS SDK](https://github.com/clerk/clerk-ios) >= 0.66.0

## Installation

### Swift Package Manager

Add ConvexClerk to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mellobirkan/convex-swift-clerk", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ConvexClerk", package: "convex-swift-clerk")
    ]
)
```

### Xcode

1. Go to **File > Add Package Dependencies...**
2. Enter: `https://github.com/mellobirkan/convex-swift-clerk`
3. Select your version requirements and click **Add Package**

## Setup

### 1. Configure Clerk

1. Create a Clerk application at [clerk.com](https://clerk.com)
2. Navigate to **JWT Templates** in your Clerk Dashboard
3. Create a new template named `convex` with these claims:

```json
{
  "aud": "convex",
  "sub": "{{user.id}}"
}
```

### 2. Configure Convex

Create `convex/auth.config.ts` in your Convex project:

```typescript
export default {
  providers: [
    {
      domain: "https://your-clerk-domain.clerk.accounts.dev",
      applicationID: "convex",
    },
  ]
};
```

Deploy the configuration:

```bash
npx convex dev
```

### 3. Initialize in Your App

```swift
import SwiftUI
import Clerk
import ConvexMobile
import ConvexClerk

@main
struct YourApp: App {
    init() {
        Clerk.configure(publishableKey: "pk_test_...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Create the authenticated Convex client
let client = ConvexClientWithAuth(
    deploymentUrl: "https://your-deployment.convex.cloud",
    authProvider: ClerkAuthProvider(jwtTemplate: "convex")
)
```

## API Reference

### ClerkAuthProvider

The main authentication provider that implements Convex's `AuthProvider` protocol.

#### Initialization

```swift
public init(jwtTemplate: String = "convex", signInTimeout: TimeInterval = 120)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `jwtTemplate` | `String` | `"convex"` | Name of the Clerk JWT template to use |
| `signInTimeout` | `TimeInterval` | `120` | Seconds to wait for sign-in completion |

#### Methods

##### `login() async throws -> ClerkCredentials`

Performs authentication. If the user is already signed in, returns credentials immediately. Otherwise, waits for sign-in completion (up to `signInTimeout` seconds).

```swift
do {
    let credentials = try await authProvider.login()
    print("Authenticated: \(credentials.userId)")
} catch {
    print("Login failed: \(error.localizedDescription)")
}
```

##### `loginFromCache() async throws -> ClerkCredentials`

Attempts to restore credentials from an existing Clerk session without waiting for user interaction. Throws if no active session exists.

```swift
do {
    let credentials = try await authProvider.loginFromCache()
    print("Session restored: \(credentials.userId)")
} catch ClerkAuthError.noActiveSession {
    print("No cached session, show sign-in UI")
}
```

##### `logout() async throws`

Signs out the current user from Clerk.

```swift
try await authProvider.logout()
```

##### `extractIdToken(from:) -> String`

Extracts the JWT token from credentials. Used internally by `ConvexClientWithAuth`.

### ClerkCredentials

A `Sendable` struct containing authentication data.

```swift
public struct ClerkCredentials: Sendable {
    public let userId: String   // Clerk user ID
    public let idToken: String  // JWT token for Convex
}
```

### ClerkAuthError

Error types thrown by `ClerkAuthProvider`.

| Case | Description |
|------|-------------|
| `.clerkNotLoaded` | Clerk SDK not initialized. Call `Clerk.configure()` first. |
| `.noActiveSession` | No signed-in Clerk session exists. |
| `.tokenRetrievalFailed(String)` | JWT token generation failed. Check your template configuration. |
| `.signInTimeout` | User did not complete sign-in within the timeout period. |

## Usage Examples

### Basic Authentication Flow

```swift
import SwiftUI
import Clerk
import ConvexMobile
import ConvexClerk

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var showSignIn = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainAppView()
            } else {
                Button("Sign In") {
                    showSignIn = true
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .task {
            // Try to restore session on launch
            do {
                _ = try await client.loginFromCache()
                isAuthenticated = true
            } catch {
                isAuthenticated = false
            }
        }
    }
}
```

### Observing Authentication State

```swift
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        client.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .authenticated(let credentials):
                    self?.isAuthenticated = true
                    self?.userId = credentials.userId
                case .unauthenticated:
                    self?.isAuthenticated = false
                    self?.userId = nil
                case .loading:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
```

### Using Authentication in Convex Functions

```typescript
// convex/users.ts
import { query, mutation } from "./_generated/server";

export const currentUser = query({
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return null;
        }
        
        return await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .unique();
    },
});

export const createUser = mutation({
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            throw new Error("Not authenticated");
        }
        
        return await ctx.db.insert("users", {
            clerkId: identity.subject,
            createdAt: Date.now(),
        });
    },
});
```

### Custom JWT Template

```swift
// Use a custom JWT template name
let authProvider = ClerkAuthProvider(
    jwtTemplate: "my-custom-template",
    signInTimeout: 60  // 1 minute timeout
)

let client = ConvexClientWithAuth(
    deploymentUrl: "https://your-deployment.convex.cloud",
    authProvider: authProvider
)
```

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| `clerkNotLoaded` | `Clerk.configure()` not called | Initialize Clerk in your App's `init()` |
| `noActiveSession` | No user signed in | Present Clerk sign-in UI first |
| `tokenRetrievalFailed` | JWT template misconfigured | Verify template name and claims in Clerk Dashboard |
| `signInTimeout` | User didn't complete sign-in | Increase `signInTimeout` or check UI flow |

### Debug Checklist

1. Verify Clerk publishable key is correct
2. Confirm JWT template name matches between Clerk Dashboard and code
3. Ensure `auth.config.ts` domain matches your Clerk domain
4. Check Xcode console for detailed error messages
5. Verify Clerk SDK is loaded before calling auth methods

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- [Convex Documentation](https://docs.convex.dev/)
- [Convex Swift Quickstart](https://docs.convex.dev/quickstart/ios)
- [Clerk iOS Documentation](https://clerk.com/docs/quickstarts/ios)
- [Convex Auth Documentation](https://docs.convex.dev/auth)

## Support

- [Convex Discord](https://convex.dev/community)
- [Clerk Discord](https://discord.com/invite/b5rXHjAg7A)
- [GitHub Issues](https://github.com/mellobirkan/convex-swift-clerk/issues)
