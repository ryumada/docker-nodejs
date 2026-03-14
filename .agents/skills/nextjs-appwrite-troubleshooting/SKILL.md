---
name: Next.js & Appwrite Troubleshooting
category: Guide
description: Solutions for common issues encountered when integrating Appwrite with Next.js (App Router), including hydration, CSP, and session management.
---

# Next.js & Appwrite Troubleshooting

This skill documents solutions for common issues when building Next.js applications with Appwrite.

## 1. Hydration Mismatch with Radix UI

**Issue**: `Error: Text content does not match server-rendered HTML` or similar hydration errors when using Radix UI components (like `DropdownMenu`, `Dialog`) inside Server Components.

**Cause**: Radix UI generates random IDs for accessibility. On the server (SSR), these IDs differ from the ones generated on the client, causing a mismatch.

**Solution**:
- Ensure any component using Radix UI primitives has the `"use client"` directive at the top.
- If a Server Component (like `AppSidebar`) imports Client Components that use Radix, consider making the parent component a Client Component if it handles state or interactivity.

```tsx
"use client" // <--- precise fix

import { Sidebar, SidebarContent } from "@/components/ui/sidebar"
// ...
```

## 2. Content Security Policy (CSP) Blocking Scripts

**Issue**: Inline scripts (e.g., Turnstile, analytics) are blocked by the browser with a CSP error.

**Cause**: Strict CSP headers prevent inline execution unless a nonce or hash is provided.

**Solution**:
- Configure CSP in `middleware.ts`.
- Allow `unsafe-inline` if strictly necessary for development or certain libraries, OR use a nonce-based approach.

**Example `middleware.ts`**:
```ts
import { NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
    const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
    const cspHeader = `
        default-src 'self';
        script-src 'self' 'nonce-${nonce}' 'strict-dynamic';
        style-src 'self' 'unsafe-inline';
        // ...
    `;

    const response = NextResponse.next();
    response.headers.set('Content-Security-Policy', cspHeader);
    return response;
}
```

## 3. Appwrite Session Cookies on Localhost

**Issue**: `middleware.ts` cannot validate the session cookie `a_session_[PROJECT_ID]`, causing redirects to `/login` even after successful login.

**Cause**: Appwrite session cookies are set with `SameSite=None; Secure`. Most browsers **reject** Secure cookies on unsecured HTTP connections (localhost).

**Solution**:
- **On Localhost**: Disable server-side session cookies check in `middleware.ts` or `proxy.ts`. Rely on client-side session checking (`AppwriteProvider`).
- **On Production**: Ensure HTTPS is enabled. The cookies will work correctly.
- **Alternative**: Use a custom domain for Appwrite to share the top-level domain, avoiding cross-site cookie issues.

## 4. Middleware Filename

**Issue**: Middleware logic is ignored.

**Cause**: Next.js specifically looks for `middleware.ts` (or `.js`) in the root or `src/` directory. Files named `proxy.ts` or inside `src/lib/` are NOT automatically executed as middleware.

**Solution**:
- Rename your middleware file to `src/middleware.ts`.
- Export the function as `middleware`.
- Ensure `config.matcher` is correctly defined.

## 5. Magic Link Callback Hang

**Issue**: The application hangs indefinitely on the "Verifying..." screen after clicking a Magic Link, and user is never redirected to the dashboard.

**Cause**: Network stalls, packet drops, or database cold starts (common in Docker environments) can cause the server-side profile fetch (`getProfile`) to hang indefinitely without throwing an error.

**Solution**:
- Wrap the critical server-side fetch in a **timeout race** (e.g., `Promise.race`).
- If the fetch takes too long, reject the promise to trigger error handling or a retry UI, preventing the infinite spinner.

**Example**:
```tsx
const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error("Request timed out")), 5000)
);

try {
    const result = await Promise.race([
        getProfile(userId),
        timeoutPromise
    ]);
    // ... handle success
} catch (error) {
    // ... handle timeout/error
}
```

## 6. Source Map 404 (installHook.js)

**Issue**: Console error: `Source map error: Error: request failed with status 404` for `installHook.js.map`.

**Cause**: This is a **benign warning** caused by the **React DevTools** browser extension. The extension injects `installHook.js` into the page and tries to load its source map relative to your local server, which doesn't exist.

**Solution**:
- **Ignore it**. It is a local development artifact and does not affect the application's functionality or production builds.
