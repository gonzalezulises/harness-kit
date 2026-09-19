import * as Sentry from "@sentry/nextjs";
import { scrubEvent } from "./sentry-scrub";

// Every knob is read from the environment and mirrored by bin/sentry-check, so
// the gate checks the same values the SDK uses. Hardcoding one here would make
// the gate check a fiction.
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,

  // Separates preview noise from production incidents. An alert channel that
  // fires on every branch deploy gets muted, and then nothing is monitored.
  environment: process.env.SENTRY_ENVIRONMENT ?? "development",

  // Ties every event to the commit that shipped it. With commits associated in
  // Sentry, this is what makes suspect commits work.
  release: process.env.SENTRY_RELEASE,

  sampleRate: Number(process.env.SENTRY_SAMPLE_RATE ?? 1),
  tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? 0),

  // Off by default: headers, cookies and IP addresses are personal data, and a
  // bug tracker is not the place to discover you are storing it.
  sendDefaultPii: process.env.SENTRY_SEND_DEFAULT_PII === "true",

  // La URL no la filtra sendDefaultPii: un token en el path —enlace mágico,
  // portal de cliente— sale vivo hacia Sentry con el primer error. Ver
  // sentry-scrub.ts.
  beforeSend: (event) => scrubEvent(event),
  beforeSendTransaction: (event) => scrubEvent(event),

  // Local runs would otherwise fill the production project with noise from
  // code that was never deployed.
  enabled: process.env.NODE_ENV === "production",
});
