function assertValue<T>(value: T | undefined, name: string): T {
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export const siteUrl = assertValue(
  process.env.NEXT_PUBLIC_SITE_URL,
  "NEXT_PUBLIC_SITE_URL"
);

export const enokiApiKey = assertValue(
  process.env.NEXT_PUBLIC_ENOKI_API_KEY,
  "NEXT_PUBLIC_ENOKI_API_KEY"
);

export const googleClientId = assertValue(
  process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID,
  "NEXT_PUBLIC_GOOGLE_CLIENT_ID"
);
