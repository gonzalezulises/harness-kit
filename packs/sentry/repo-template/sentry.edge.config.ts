import * as Sentry from "@sentry/nextjs";
import { scrubEvent } from "./sentry-scrub";

// The edge runtime is a separate process with its own initialisation: middleware
// and edge route handlers do not inherit sentry.server.config.ts.
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.SENTRY_ENVIRONMENT ?? "development",
  release: process.env.SENTRY_RELEASE,
  sampleRate: Number(process.env.SENTRY_SAMPLE_RATE ?? 1),
  tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? 0),
  sendDefaultPii: process.env.SENTRY_SEND_DEFAULT_PII === "true",

  // La URL no la filtra sendDefaultPii: un token en el path —enlace mágico,
  // portal de cliente— sale vivo hacia Sentry con el primer error. Ver
  // sentry-scrub.ts.
  beforeSend: (event) => scrubEvent(event),
  beforeSendTransaction: (event) => scrubEvent(event),
  enabled: process.env.NODE_ENV === "production",
});
