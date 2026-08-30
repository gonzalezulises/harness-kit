import * as Sentry from "@sentry/nextjs";

export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./sentry.server.config");
  }
  if (process.env.NEXT_RUNTIME === "edge") {
    await import("./sentry.edge.config");
  }
}

// Without this export, errors thrown in server components, route handlers and
// server actions never reach Sentry — the app keeps serving 500s and the
// project stays empty. bin/sentry-check preflight fails when it is missing.
export const onRequestError = Sentry.captureRequestError;
