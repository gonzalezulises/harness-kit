// Redacta secretos que viajan en la URL antes de que el evento salga del
// proceso.
//
// Por qué existe: `sendDefaultPii: false` NO toca la URL. Sentry envía la URL
// de la petición, el nombre de la transacción, el Referer y cada breadcrumb de
// navegación tal cual. Una app que pone un token de capacidad en el path
// —/mi-perfil/<token>, /encuesta/<token>, un enlace mágico— entrega ese token
// vivo a un tercero en cuanto ocurre el primer error, y quien tenga lectura del
// proyecto de Sentry puede usarlo. El token no es PII: es una credencial.
//
// La redacción es por defecto y no requiere configuración, porque un pack de
// observabilidad que hay que endurecer a mano se instala sin endurecer.

/** Nombres de query param cuyo valor nunca debe salir. */
const SENSITIVE_QUERY_KEYS =
  /^(token|access_token|refresh_token|id_token|key|api[-_]?key|secret|password|passwd|pwd|auth|authorization|session|sid|code|sig|signature|state|nonce|invite|magic)$/i;

/**
 * Un segmento de path que parece una credencial: largo y con la entropía de un
 * identificador generado, no de una palabra. Cubre hex, base64url, nanoid y
 * UUID. Los slugs legibles ("mi-perfil", "encuesta-evaluacion") no entran
 * porque son cortos o sólo letras y guiones.
 */
function looksLikeSecret(segment: string): boolean {
  if (segment.length < 16) return false;
  if (/^[0-9a-f]{16,}$/i.test(segment)) return true; // hex
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(segment)) return true;
  if (!/^[A-Za-z0-9_-]+$/.test(segment)) return false;
  const hasDigit = /\d/.test(segment);
  const hasLetter = /[A-Za-z]/.test(segment);
  return hasDigit && hasLetter;
}

/** Rutas cuyo siguiente segmento es siempre un secreto, por si la heurística no basta. */
function configuredTokenRoutes(): readonly string[] {
  const raw = process.env.NEXT_PUBLIC_SENTRY_TOKEN_ROUTES ?? process.env.SENTRY_TOKEN_ROUTES ?? "";
  return raw
    .split(",")
    .map((value) => value.trim().replace(/^\/+|\/+$/g, ""))
    .filter((value) => value.length > 0);
}

export const REDACTED = "[redacted]";

/** Redacta path y query de una URL. Devuelve la entrada intacta si no parsea. */
export function scrubUrl(value: string): string {
  if (!value) return value;
  const tokenRoutes = configuredTokenRoutes();
  const [withoutHash, hash] = splitOnce(value, "#");
  const [pathAndMaybeOrigin, query] = splitOnce(withoutHash, "?");

  const segments = pathAndMaybeOrigin.split("/");
  const scrubbedSegments = segments.map((segment, index) => {
    if (!segment) return segment;
    const previous = segments[index - 1];
    if (previous !== undefined && tokenRoutes.includes(previous)) return REDACTED;
    return looksLikeSecret(segment) ? REDACTED : segment;
  });

  let out = scrubbedSegments.join("/");
  if (query !== undefined) out += "?" + scrubQueryString(query);
  if (hash !== undefined) out += "#" + hash;
  return out;
}

function splitOnce(value: string, separator: string): [string, string | undefined] {
  const at = value.indexOf(separator);
  return at === -1 ? [value, undefined] : [value.slice(0, at), value.slice(at + 1)];
}

function scrubQueryString(query: string): string {
  return query
    .split("&")
    .map((pair) => {
      const [key, ...rest] = pair.split("=");
      if (rest.length === 0) return pair;
      const value = rest.join("=");
      if (SENSITIVE_QUERY_KEYS.test(decodeSafely(key))) return `${key}=${REDACTED}`;
      return looksLikeSecret(decodeSafely(value)) ? `${key}=${REDACTED}` : pair;
    })
    .join("&");
}

function decodeSafely(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

/**
 * Pasa un evento por el redactor. Se aplica a todo lo que transporta una URL:
 * la petición, el nombre de la transacción, el Referer y los breadcrumbs de
 * navegación, que son los que registran cada cambio de ruta del App Router.
 */
export function scrubEvent<T>(event: T): T {
  // Genérico sin restricción: los tipos de evento de Sentry (ErrorEvent,
  // TransactionEvent) no llevan index signature, así que exigir
  // Record<string, unknown> los rechaza en beforeSend. Se muta en su sitio y se
  // devuelve el mismo objeto, que es el contrato que Sentry espera.
  if (event === null || typeof event !== "object") return event;
  const target = event as unknown as Record<string, unknown>;

  const request = target.request as { url?: string; headers?: Record<string, string> } | undefined;
  if (request?.url) request.url = scrubUrl(request.url);
  if (request?.headers) {
    for (const header of ["Referer", "referer", "Referrer", "referrer"]) {
      const current = request.headers[header];
      if (current) request.headers[header] = scrubUrl(current);
    }
  }

  if (typeof target.transaction === "string") target.transaction = scrubUrl(target.transaction);

  const breadcrumbs = target.breadcrumbs as
    | Array<{ data?: Record<string, unknown>; message?: string }>
    | undefined;
  if (Array.isArray(breadcrumbs)) {
    for (const crumb of breadcrumbs) {
      if (typeof crumb.message === "string") crumb.message = scrubUrl(crumb.message);
      const data = crumb.data;
      if (!data) continue;
      for (const key of ["url", "from", "to", "path"]) {
        if (typeof data[key] === "string") data[key] = scrubUrl(data[key] as string);
      }
    }
  }

  return event;
}
