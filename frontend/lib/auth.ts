import { fetchAuthSession, getCurrentUser } from '@aws-amplify/auth';

export async function getIdToken(): Promise<string | null> {
  try {
    const session = await fetchAuthSession();
    return session.tokens?.idToken?.toString() ?? null;
  } catch {
    return null;
  }
}

export async function isAuthenticated(): Promise<boolean> {
  const token = await getIdToken();
  return Boolean(token);
}

/**
 * Get the authenticated user's email from Cognito
 * Returns the email or null if not authenticated
 */
export async function getUserEmail(): Promise<string | null> {
  try {
    const session = await fetchAuthSession();
    if (session.tokens?.idToken) {
      // The email is in the ID token's payload
      const payload = session.tokens.idToken.payload;
      return (payload?.email as string) || null;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Get the authenticated user's sub (UUID) from Cognito
 * This is the unique identifier for the user
 */
export async function getUserSub(): Promise<string | null> {
  try {
    const session = await fetchAuthSession();
    if (session.tokens?.idToken) {
      const payload = session.tokens.idToken.payload;
      return (payload?.sub as string) || null;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Get full user information from Cognito
 * Returns user object with username, sub, email, and other attributes
 */
export async function getUserInfo() {
  try {
    const user = await getCurrentUser();
    const session = await fetchAuthSession();
    const idTokenPayload = session.tokens?.idToken?.payload || {};

    return {
      username: user.username,
      sub: (idTokenPayload.sub as string) || '',
      email: (idTokenPayload.email as string) || '',
      name: (idTokenPayload.name as string) || '',
      givenName: (idTokenPayload.given_name as string) || '',
      familyName: (idTokenPayload.family_name as string) || '',
    };
  } catch {
    return null;
  }
}
