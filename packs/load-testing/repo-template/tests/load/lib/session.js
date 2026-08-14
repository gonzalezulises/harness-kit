// Sesión de usuario final contra Supabase.
//
// El guard de `guard.js` cubre autenticación de PLATAFORMA (IAP, protección de
// despliegue de Vercel). Esto es distinto: la aplicación exige que un usuario
// haya iniciado sesión, y sin ella las rutas con datos responden 307 hacia el
// login. Medirlas sin sesión mide redirecciones.
//
// El formato de la cookie NO viene de la documentación: se leyó del paquete
// @supabase/ssr instalado (0.12.4), que es la fuente de verdad de lo que el
// servidor va a intentar decodificar:
//
//   nombre : sb-<project-ref>-auth-token
//   valor  : "base64-" + base64url(JSON.stringify(sesión))
//
// Dos detalles que rompen esto si se asumen:
//
//   1. Es base64**url** (alfabeto con `-` y `_`), no base64 estándar.
//   2. `stringToBase64URL` NO emite relleno `=`. En k6 eso corresponde a
//      b64encode(s, 'rawurl'); usar 'url' añade relleno y el servidor descarta
//      la cookie como corrupta.

import http from 'k6/http';
import encoding from 'k6/encoding';
import { abortWithReason } from './abort.js';

const BASE64_PREFIX = 'base64-';

// El identificador del proyecto es el subdominio: https://<ref>.supabase.co
function projectRef(url) {
  const match = /^https?:\/\/([^.]+)\./.exec(url);
  return match ? match[1] : null;
}

export function supabaseSession() {
  const url = (__ENV.PERF_SUPABASE_URL || '').replace(/\/+$/, '');
  const anonKey = __ENV.PERF_SUPABASE_ANON_KEY;
  const email = __ENV.PERF_USER_EMAIL;
  const password = __ENV.PERF_USER_PASSWORD;

  const missing = [];
  if (!url) missing.push('PERF_SUPABASE_URL');
  if (!anonKey) missing.push('PERF_SUPABASE_ANON_KEY');
  if (!email) missing.push('PERF_USER_EMAIL');
  if (!password) missing.push('PERF_USER_PASSWORD');
  if (missing.length) {
    abortWithReason(
      `PERF_AUTH=supabase exige ${missing.join(', ')}. Sin sesión, las rutas ` +
        'protegidas responden una redirección al login y medirlas no dice nada ' +
        'del rendimiento de la aplicación.'
    );
  }

  const ref = projectRef(url);
  if (!ref) {
    abortWithReason(
      `no se pudo extraer el identificador del proyecto de PERF_SUPABASE_URL ("${url}"). ` +
        'Se espera la forma https://<ref>.supabase.co'
    );
  }

  // Contraseña directa y no un flujo de enlace por correo: es el único modo
  // reproducible sin intervención humana en cada corrida.
  const res = http.post(
    `${url}/auth/v1/token?grant_type=password`,
    JSON.stringify({ email: email, password: password }),
    {
      headers: { apikey: anonKey, 'Content-Type': 'application/json' },
      tags: { guard: 'true' },
    }
  );

  if (res.status !== 200) {
    let detail = '';
    try {
      const body = res.json();
      detail = body && (body.error_description || body.msg || body.error || '');
    } catch (e) {
      detail = (res.body || '').slice(0, 120);
    }
    abortWithReason(
      `Supabase rechazó las credenciales de prueba (${res.status}${detail ? `: ${detail}` : ''}). ` +
        'Verifica PERF_USER_EMAIL y PERF_USER_PASSWORD, y que ese usuario exista y esté ' +
        'confirmado en este proyecto.'
    );
  }

  const session = res.json();
  if (!session || !session.access_token) {
    abortWithReason(
      'Supabase respondió 200 pero sin access_token. La respuesta no es una sesión válida.'
    );
  }

  // 'rawurl' = base64url sin relleno, exactamente lo que produce
  // stringToBase64URL en @supabase/ssr.
  const cookieValue =
    BASE64_PREFIX + encoding.b64encode(JSON.stringify(session), 'rawurl');

  return {
    cookieName: `sb-${ref}-auth-token`,
    cookieValue: cookieValue,
    // El token también sirve para llamar a la API de Supabase directamente.
    accessToken: session.access_token,
    userId: session.user && session.user.id,
  };
}

// Cabecera Cookie explícita en lugar del frasco de cookies de k6: el valor es el
// mismo en todos los usuarios virtuales y así queda visible en el código qué se
// está enviando.
export function sessionHeaders(session) {
  return { Cookie: `${session.cookieName}=${session.cookieValue}` };
}
