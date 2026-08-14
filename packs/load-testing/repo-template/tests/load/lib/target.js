// Resolución del objetivo y sus cabeceras de autenticación.
//
// Un objetivo mal configurado NO debe medirse: mediría la página de login de la
// plataforma y reportaría latencias excelentes sin haber tocado la aplicación.
// Por eso toda falla de configuración aborta el test (exit 108) en lugar de
// degradarse a una medición sin valor.

import { abortWithReason } from './abort.js';

// Hosts que sirven pantallas de autenticación. Si el objetivo redirige a uno de
// estos, el token que se pasó es inválido, expiró, o falta.
const AUTH_HOSTS = [
  'accounts.google.com',
  'vercel.com',
  'login.microsoftonline.com',
  'auth0.com',
  'okta.com',
  'authkit.app',
];

// Los cuatro tipos de objetivo que este pack soporta. El tipo determina qué
// credencial se exige, y exigirla temprano evita el falso verde.
const AUTH_MODES = {
  // Sin capa de autenticación de plataforma.
  none: () => ({}),

  // Preview de Vercel con Deployment Protection activa.
  // El secreto se obtiene en Vercel > Project > Settings > Deployment Protection
  // > Protection Bypass for Automation.
  'vercel-bypass': () => {
    const secret = __ENV.VERCEL_AUTOMATION_BYPASS_SECRET;
    if (!secret) {
      abortWithReason(
        'PERF_AUTH=vercel-bypass pero falta VERCEL_AUTOMATION_BYPASS_SECRET. ' +
          'Sin ese secreto k6 mediría la pantalla de autenticación de Vercel.'
      );
    }
    return {
      'x-vercel-protection-bypass': secret,
      // Fija la cookie de bypass para que las navegaciones siguientes no
      // vuelvan a chocar con la protección.
      'x-vercel-set-bypass-cookie': 'samesitenone',
    };
  },

  // Cloud Run detrás de IAP. k6 no puede ejecutar gcloud, así que el ID token
  // se genera FUERA y se inyecta por entorno:
  //
  //   export PERF_IAP_TOKEN="$(gcloud auth print-identity-token \
  //     --audiences=<OAUTH_CLIENT_ID_DE_IAP>)"
  //
  // El audience DEBE ser el client ID de OAuth de IAP. Un token válido con el
  // audience equivocado produce 401 "Invalid JWT audience", no un error de
  // credencial — el síntoma engaña. El token vive ~1 hora: para pruebas largas,
  // regenéralo antes de cada corrida.
  iap: () => {
    const token = __ENV.PERF_IAP_TOKEN;
    if (!token) {
      abortWithReason(
        'PERF_AUTH=iap pero falta PERF_IAP_TOKEN. Genera un ID token con ' +
          '`gcloud auth print-identity-token --audiences=<IAP_OAUTH_CLIENT_ID>`.'
      );
    }
    return { Authorization: `Bearer ${token}` };
  },

  // Sesión de usuario final contra Supabase. Aquí SÓLO se valida que estén las
  // variables: autenticarse es una petición HTTP, y k6 no permite peticiones en
  // el contexto de inicialización. La sesión se obtiene en setup().
  supabase: () => {
    const missing = [];
    if (!__ENV.PERF_SUPABASE_URL) missing.push('PERF_SUPABASE_URL');
    if (!__ENV.PERF_SUPABASE_ANON_KEY) missing.push('PERF_SUPABASE_ANON_KEY');
    if (!__ENV.PERF_USER_EMAIL) missing.push('PERF_USER_EMAIL');
    if (!__ENV.PERF_USER_PASSWORD) missing.push('PERF_USER_PASSWORD');
    if (missing.length) {
      abortWithReason(`PERF_AUTH=supabase exige ${missing.join(', ')}.`);
    }
    return {};
  },

  // Token propio de la aplicación (no de la plataforma).
  bearer: () => {
    const token = __ENV.PERF_BEARER;
    if (!token) {
      abortWithReason('PERF_AUTH=bearer pero falta PERF_BEARER.');
    }
    return { Authorization: `Bearer ${token}` };
  },
};

export function resolveTarget() {
  const base = (__ENV.PERF_TARGET || '').replace(/\/+$/, '');
  if (!base) {
    abortWithReason(
      'PERF_TARGET no está definido. Exporta la URL base del objetivo, ' +
        'por ejemplo PERF_TARGET=https://mi-preview.vercel.app'
    );
  }
  if (!base.startsWith('http://') && !base.startsWith('https://')) {
    abortWithReason(`PERF_TARGET debe incluir el esquema. Recibido: ${base}`);
  }

  const mode = __ENV.PERF_AUTH || 'none';
  const buildHeaders = AUTH_MODES[mode];
  if (!buildHeaders) {
    abortWithReason(
      `PERF_AUTH="${mode}" no es válido. Usa uno de: ${Object.keys(AUTH_MODES).join(', ')}.`
    );
  }

  return {
    base,
    mode,
    headers: buildHeaders(),
    // Ruta que prueba que la aplicación real respondió, no un intermediario.
    guardPath: __ENV.PERF_GUARD_PATH || '/',
    // Texto que debe aparecer en el cuerpo de guardPath. Elige algo que sólo
    // exista en tu aplicación: un id de contenedor, el nombre del producto.
    appMarker: __ENV.PERF_APP_MARKER || '',
    routes: parseRoutes(),
  };
}

// Rutas a medir. Formato: "GET /,GET /api/records" o sólo "/,/api/records".
function parseRoutes() {
  const raw = __ENV.PERF_ROUTES || '/';
  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const parts = entry.split(/\s+/);
      return parts.length > 1
        ? { method: parts[0].toUpperCase(), path: parts[1] }
        : { method: 'GET', path: parts[0] };
    });
}

export function isAuthHost(url) {
  return AUTH_HOSTS.some((host) => url.includes(host));
}

export { AUTH_HOSTS };
export { abortWithReason };
