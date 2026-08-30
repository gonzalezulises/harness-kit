import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ?? "development",
  release: process.env.NEXT_PUBLIC_SENTRY_RELEASE,

  sampleRate: Number(process.env.NEXT_PUBLIC_SENTRY_SAMPLE_RATE ?? 1),
  tracesSampleRate: Number(process.env.NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE ?? 0),

  // Replay records what the user did before the error. Sampling ordinary
  // sessions is a cost decision; sampling the ones that errored is not — those
  // are the only sessions anybody ever watches.
  replaysSessionSampleRate: Number(
    process.env.NEXT_PUBLIC_SENTRY_REPLAYS_SESSION_SAMPLE_RATE ?? 0,
  ),
  replaysOnErrorSampleRate: Number(
    process.env.NEXT_PUBLIC_SENTRY_REPLAYS_ON_ERROR_SAMPLE_RATE ?? 0,
  ),

  integrations: [
    Sentry.replayIntegration({
      // Text and inputs are masked by default. Turning this off in a project
      // that handles client data records personal information into a replay.
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],

  sendDefaultPii: process.env.NEXT_PUBLIC_SENTRY_SEND_DEFAULT_PII === "true",
  enabled: process.env.NODE_ENV === "production",
});

// Powers navigation instrumentation in the App Router. Without it, client-side
// route changes are invisible to tracing.
export const onRouterTransitionStart = Sentry.captureRouterTransitionStart;
