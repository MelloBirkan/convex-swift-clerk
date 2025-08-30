# Convex Swift - Clerk Integration

This library works with the core [Convex Swift](https://github.com/get-convex/convex-swift) library and provides support for using Clerk authentication in `ConvexClientWithAuth`.

The integration uses Clerk's authentication system to provide secure user authentication for your Convex application. Users authenticate through Clerk's UI components and receive JWT tokens that work seamlessly with Convex.

## Getting Started

First, if you haven't started a Convex application yet, head over to the [Convex Swift iOS quickstart](https://docs.convex.dev/quickstart/ios) to get the basics down. It will get you up and running with a Convex dev deployment and a basic Swift application that communicates with it.

Once you have a working Convex + Swift application, follow these steps to integrate with Clerk.

> [!NOTE]
> There are several moving parts to getting auth set up. If you run into trouble, check out the [Convex auth docs](https://docs.convex.dev/auth) and join our [Discord community](https://convex.dev/community) to get help.

## Setup

### 1. Configure Clerk

1. Create a Clerk application at [clerk.com](https://clerk.com)
2. In your Clerk Dashboard, navigate to **JWT Templates**
3. Create a new JWT template named `convex` (or your preferred name)
4. Configure the template with the following claims:
   ```json
   {
     "aud": "convex",
     "sub": "{{user.id}}"
   }
   ```

### 2. Configure Convex

Create a `convex/auth.config.ts` file in your Convex project:

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

Run `npx convex dev` to sync the auth configuration.

### 3. Install Dependencies

Add this package to your Xcode project:

#### Using Swift Package Manager

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/yourusername/ConvexClerk`
3. Click **Add Package**

#### Using Package.swift

Add to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/yourusername/ConvexClerk", from: "1.0.0")
]
```

### 4. Configure Your iOS App

1. Initialize Clerk in your App file:

```swift
import SwiftUI
import Clerk

@main
struct YourApp: App {
  init() {
    Clerk.configure(publishableKey: "YOUR_CLERK_PUBLISHABLE_KEY")
  }
  
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
```

2. Set up the Convex client with Clerk authentication:

```swift
import ConvexMobile
import ConvexClerk

let client = ConvexClientWithAuth(
  deploymentUrl: "YOUR_CONVEX_DEPLOYMENT_URL",
  authProvider: ClerkAuthProvider(jwtTemplate: "convex")
)
```

### 5. Implement Authentication UI

Create a view to handle authentication:

```swift
import SwiftUI
import Clerk

struct AuthView: View {
  @State private var showSignIn = false
  
  var body: some View {
    VStack {
      if Clerk.shared.user != nil {
        Text("Signed in as \(Clerk.shared.user?.emailAddresses.first?.emailAddress ?? "")")
        Button("Sign Out") {
          Task {
            try await client.logout()
          }
        }
      } else {
        Button("Sign In") {
          showSignIn = true
        }
        .sheet(isPresented: $showSignIn) {
          SignInView()
        }
      }
    }
  }
}

struct SignInView: View {
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    NavigationView {
      ClerkAuthView()
        .navigationTitle("Sign In")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
          }
        }
    }
  }
}
```

## Usage

### Authentication Methods

The `ClerkAuthProvider` class provides three main methods:

#### login()
Initiates the authentication flow. If the user is already signed in, returns existing credentials. Otherwise, waits for the user to complete sign-in.

```swift
Task {
  do {
    let credentials = try await client.login()
    print("Logged in with user ID: \(credentials.userId)")
  } catch {
    print("Login failed: \(error)")
  }
}
```

#### loginFromCache()
Attempts to restore a session from cached credentials without showing UI.

```swift
Task {
  do {
    let credentials = try await client.loginFromCache()
    print("Restored session for user: \(credentials.userId)")
  } catch {
    print("No cached session available")
  }
}
```

#### logout()
Signs the user out and clears the session.

```swift
Task {
  try await client.logout()
}
```

### Reacting to Authentication State

The `ConvexClientWithAuth.authState` field is a Publisher that contains the latest authentication state:

```swift
import Combine

class AuthViewModel: ObservableObject {
  @Published var isAuthenticated = false
  private var cancellables = Set<AnyCancellable>()
  
  init() {
    client.authState
      .sink { state in
        switch state {
        case .authenticated(let credentials):
          self.isAuthenticated = true
          print("User ID: \(credentials.userId)")
        case .unauthenticated:
          self.isAuthenticated = false
        case .loading:
          print("Loading auth state...")
        }
      }
      .store(in: &cancellables)
  }
}
```

### Using Authentication in Convex Functions

Once authenticated, you can access user information in your Convex backend functions:

```typescript
import { query } from "./_generated/server";
import { auth } from "./_generated/server";

export const getUser = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    return {
      userId: identity.subject,
      // Additional user data from your database
    };
  },
});
```

## JWT Template Configuration

The `ClerkAuthProvider` uses a JWT template to generate tokens for Convex. By default, it looks for a template named "convex", but you can specify a different template name:

```swift
let authProvider = ClerkAuthProvider(jwtTemplate: "custom-template-name")
```

Make sure your JWT template in the Clerk Dashboard includes the necessary claims for Convex authentication.

## Troubleshooting

### Common Issues

1. **"Clerk not loaded" error**: Ensure `Clerk.configure()` is called in your App's init method
2. **"No signed-in Clerk session found"**: User needs to sign in first before calling `loginFromCache()`
3. **"Clerk token API unavailable"**: Check that your JWT template exists and is properly configured
4. **Authentication timeout**: The provider waits up to 2 minutes for sign-in to complete

### Debug Tips

- Verify your Clerk publishable key is correct
- Check that your JWT template name matches between Clerk Dashboard and your code
- Ensure your Convex auth.config.ts is properly configured
- Check the Xcode console for detailed error messages

## Requirements

- iOS 16.0+
- Swift 5.9+
- [Clerk iOS SDK](https://github.com/clerk/clerk-ios) >= 0.66.0
- [Convex Swift](https://github.com/get-convex/convex-swift) >= 0.5.5

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions:
- [Convex Discord](https://convex.dev/community)
- [Clerk Discord](https://discord.com/invite/b5rXHjAg7A)
- [GitHub Issues](https://github.com/yourusername/ConvexClerk/issues)